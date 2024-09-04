#!/bin/bash
# Copyright (c) 2024 Gilad Odinak

# aws account and key
. awskey.inc

# Variables
. apigw-test-config.inc

export AWS_PAGER=""
#set -e
#set -x

# Create a Key Pair
rm -f $KEY_NAME.pem
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' \
    --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem
echo "Created key pair: $KEY_NAME"

# Create a Security Group
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP_NAME \
    --description "Security group for the APIGWTest http server" \
    --query 'GroupId' --output text)
echo "Created security group: $SECURITY_GROUP_NAME with ID $SECURITY_GROUP_ID"

# Allow Inbound Traffic on Port 3000
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID \
    --protocol tcp --port 3000 --cidr 0.0.0.0/0  > /dev/null
echo "Allowed inbound traffic on port 3000"

# Allow Inbound Traffic on Port 22 (SSH)
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
echo "Allowed inbound traffic on port 22 (SSH)"

# Optional User Data Script
USER_DATA=$(cat <<EOF
#!/bin/bash
EOF
)

# Launch an EC2 Instance with User Data
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data "$USER_DATA" \
    --tag-specifications \
        "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "Launched EC2 instance with ID: $INSTANCE_ID"

# Wait until the instance is running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get the Public IP Address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

echo "EC2 instance is running at IP: $PUBLIC_IP"

# Check if SSH port 22 is open
echo "Waiting for EC2 instance sshd server ..."
sleep 5
until nc -zv $PUBLIC_IP 22 ; do
    echo "Waiting for EC2 instance sshd server ..."
    sleep 5
done
echo "sshd listening on port 22. Proceeding with deployment."

# SSH into the EC2 instance and install nodejs
echo "Installing nodejs"
ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP > /dev/null 2>&1 <<EOF
#!/bin/bash
sudo yum update -y 
sudo yum install -y nodejs 
EOF

# Transfer the apiserver.js file to the EC2 instance
scp -i $KEY_NAME.pem apiserver.js ec2-user@$PUBLIC_IP:/home/ec2-user/apiserver.js
echo "Transferred apiserver.js to the EC2 instance"

# SSH into the EC2 instance and run the server
echo "Starting the EC2 HTTP server"
ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP > /dev/null 2>&1 <<EOF
#!/bin/bash
cd /home/ec2-user
nohup node apiserver.js < /dev/null > /dev/null 2>&1  &
EOF

echo "Waiting for the EC2 HTTP server ..."
sleep 5
until nc -zv $PUBLIC_IP 3000 ; do
    echo "Waiting for the EC2 HTTP server ..."
    sleep 5
done
echo "EC2 HTTP server is running at: http://$PUBLIC_IP:3000"

echo "Deploying Lambda API server"
rm -f apilambda.zip
zip apilambda.zip apilambda.js > /dev/null

aws lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime nodejs18.x \
    --role arn:aws:iam::$AWS_ACCOUNT_ID:role/$LAMBDA_ROLE \
    --handler apilambda.handler \
    --zip-file fileb://apilambda.zip \
    --publish > /dev/null

# Create HTTP API
echo "Creating an HTTP API Gateway"
API_ID=$(aws apigatewayv2 create-api \
    --name $APIGW_NAME \
    --protocol-type HTTP \
    --description "APIGWTest-HTTP-Gateway" \
    --query 'ApiId' \
    --output text)

# Adding default stage does not change the path
# Adding name stage adds the stage name between base path and api path
aws apigatewayv2 create-stage \
    --api-id $API_ID \
    --stage-name '$default' \
    --auto-deploy > /dev/null

# Create Route for EC2 server
EC2_ROUTE_ID=$(aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key "ANY /${EC2_API_PATH}" \
    --query 'RouteId' \
    --output text)

# Create integration for the Lambda server
EC2_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type HTTP_PROXY \
    --integration-method ANY \
    --integration-uri http://${PUBLIC_IP}:3000 \
    --payload-format-version 1.0 \
    --request-parameters "{\"overwrite:path\": \"\$request.path\"}" \
    --query 'IntegrationId' \
    --output text)

aws apigatewayv2 update-route \
    --api-id $API_ID \
    --route-id $EC2_ROUTE_ID \
    --target integrations/$EC2_INTEGRATION_ID > /dev/null

# Create Route for Lambda server
LAMBDA_ROUTE_ID=$(aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key "ANY /${LAMBDA_API_PATH}" \
    --query 'RouteId' \
    --output text)

# Create integration for the Lambda server
LAMBDA_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type AWS_PROXY \
    --integration-method POST \
    --integration-uri arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_NAME \
    --payload-format-version 2.0 \
    --query 'IntegrationId' \
    --output text)

aws apigatewayv2 update-route \
    --api-id $API_ID \
    --route-id $LAMBDA_ROUTE_ID \
    --target integrations/$LAMBDA_INTEGRATION_ID > /dev/null

# Create a trigger to invoke the lambda from the api gateway
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id lambda-$(uuidgen) \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*/${LAMBDA_API_PATH} \
    > /dev/null

# Output public IP and API Gateway URL
API_URL=$(aws apigatewayv2 get-api \
    --api-id $API_ID \
    --query 'ApiEndpoint' \
    --output text)

echo "API Gateway URL: $API_URL"

echo "Deployment complete."

echo
echo "Testing EC2: $API_URL/api1?param=value"
curl $API_URL/api1?param=value
echo
echo "Testing Lambda: $API_URL/api2?param=value"
curl $API_URL/api2?param=value
