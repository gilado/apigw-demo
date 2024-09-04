export AWS_REGION="us-west-2"

# EC2 Configuration 
KEY_NAME="APIGWTestKeyPair"
SECURITY_GROUP_NAME="APIGWTestSecurityGroup"
INSTANCE_NAME="APIGWTestEC2"
INSTANCE_TYPE="t4g.nano"        # Arm
AMI_ID="ami-018360301dddadc80"  # Arm

# Lambda Configuration 
LAMBDA_NAME="APIGWTestLambda"
LAMBDA_ROLE="APIGWTestLambdaRole" # See README.md

# API Gateway Configuration
APIGW_NAME="APIGWTestGateway"
EC2_API_PATH="api1"
LAMBDA_API_PATH="api2"
