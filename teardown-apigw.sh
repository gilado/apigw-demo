#!/bin/bash
# Copyright (c) 2024 Gilad Odinak

# aws account and key
. awskey.inc

# Variables
. apigw-test-config.inc

export AWS_PAGER=""

# Get the HTTP API Gateway ID
API_ID=$(aws apigatewayv2 get-apis \
    --query "Items[?Name=='$APIGW_NAME'].ApiId" \
    --output text)

if [ -z "$API_ID" ]; then
    echo "HTTP api gateway '$APIGW_NAME' does not exist."
else
    echo "Deleting HTTP api gateway $APIGW_NAME"
    aws apigatewayv2 delete-api --api-id $API_ID
fi

LAMBDA_ARN=$(aws lambda get-function \
    --function-name "$LAMBDA_NAME" \
    --query 'Configuration.FunctionArn' \
    --output text 2>/dev/null)

# Check if the Lambda function ARN is not empty
if [ -z "$LAMBDA_ARN" ]; then
    echo "Lambda function '$LAMBDA_NAME' does not exist."
else
    echo "Deleting Lambda function $LAMBDA_NAME"
    aws lambda delete-function --function-name "$LAMBDA_NAME"
fi
rm -f apilambda.zip
    
# Get the Instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
    --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "EC2 instance '$INSTANCE_NAME' does not exist."
else
    # Terminate the EC2 Instance
    echo "Terminating EC2 instance named '$INSTANCE_NAME' (if running) ..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null

    # Wait until the instance is terminated
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID > /dev/null
    echo "Running EC2 instance(s) named '$INSTANCE_NAME' terminated."
fi

# Delete the Security Group
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --group-names $SECURITY_GROUP_NAME \
    --query "SecurityGroups[*].GroupId" \
    --output text 2>/dev/null)

if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security group '$SECURITY_GROUP_NAME' does not exist."
else
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID > /dev/null
    echo "Deleted security group: $SECURITY_GROUP_NAME"
fi

# Delete the Key Pair
aws ec2 delete-key-pair --key-name $KEY_NAME > /dev/null
rm -f $KEY_NAME.pem
echo "Deleted key pair $KEY_NAME and removed local .pem file"

echo "Teardown complete."
