# apigw-demo
Proof of Concept using AWS HTTP API Gateway to route request to server running on EC2 and as a Lambda

Copyright (c) 2024 Gilad Odinak

## Overview

This project demonstrates how an HTTP API gateway can be used
to route API requests to different services, mixing EC2 instances
and Lambda functions. Further, API endpoints can be switched
on the fly from one service to another by reconfiguring the 
API gateway routes. 

### Demo building blocks

-   EC2 instance running an HTTP server
    -   Create security group allowing access on port 3000 (server) and 
        port 22 (instance ssh)
    -   Provision EC2 instance
    -   Remotely install node.js
    -   Remotely deploy server code
    -   The server responds to HTTP requests with a text message that
        identifies it as EC2 based server, echos the request url, and the 
        instance ip address
-   Lambda function that implements an HTTP server 
    -   Create Lambda, deploy server code
    -   The lambda responds to HTTP requests with a text message that
        identifies it as Lambda based server, echos the request url, and
        the container ip address
-   HTTP API gateway
    -   Create the gateway
    -   Configure it to route two endpoints, one to the EC2 server, the 
        other to the Lambda server

### Deployment

The demo is deployed programmatically by the deploy-apigw.sh script.
At the end of the deployment the script issues two HTTP GET request,
one to each server using their endpoint urls.

The demo can be removed from the AWS account by running the 
teardown-apigw.sh script.

### Pre-Requisites

0. Note the Account ID of the account to which the demo will be deployed.

1. Create a Role called APIGWTestLambdaRole, with these permission policies
- AWSLambdaBasicExecutionRole
- AWSLambdaExecute
- AWSLambdaRole

2. Create a custom Policy called PassRole, with this custom permission
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::<Account ID>:role/APIGWTestLambdaRole"
        }
    ]
}

3. Select a user, or create a new user, with these permission policies
- PowerUserAccess
- PassRole

Note: It is more secure to create a dedicated user that does not have console access.

4. Create API Access Key for this user

5. Place the AWS account id, access key id, and access key secret in the 
   file awskey.inc

### License

The MIT License [https://opensource.org/license/MIT]
