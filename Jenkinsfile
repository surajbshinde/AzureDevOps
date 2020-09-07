node {
    def whImage

    stage ("Get Parameters")
    {
        checkout scm
        List props = []
        List params = [        
            string(name: 'Account_Name', description: 'Please Enter the name of the customer.'),
            string(name: 'Tieto_ENV_Name', description: 'Please Enter the env for which you want to deploy the db (ref/ci/dev) (Note: Only lowercase values allowed).'),
            credentials(name: 'CREDENTIALS', description: 'AWS Credentials', credentialType: "Username with password"),
            choice(name: 'Region', description: 'Please select the AWS Region', choices: 'eu-west-1\neu-west-2\neu-west-3\neu-central-1\nus-west-1\nus-west-2\nus-east-2\nus-east-1\nap-northeast-1\nap-northeast-2\nap-northeast-3\nap-south-1\nap-southeast-1\nap-southeast-2\nca-central-1\ncn-north-1\ncn-northwest-1\nsa-east-1'),
            string(name: 'Instance_Type', description: 'Enter the Instance type'),
            string(name: 'AMI', description: 'Enter the AMI'),
            // string(name: 'VPC', description: 'Enter the VPC id'),
            // string(name: 'ASGSubnets', description: 'Enter the ASG Subnet'),
            // string(name: 'LBSubnets', description: 'Enter the LB Subnet'),
            // string(name: 'LBSubnets2', description: 'Enter the LB Subnet'),
            choice(name: "LB_Schema", description: "Type of Application LB", choices: "internal\ninternet-facing"),
            string(name: 'KeyName', description: 'Enter the Key name'),
            // string(name: 'AppSecurityGroup', description: 'Enter the App Security Group Id'),
            // string(name: 'AppLBSecurityGroup', description: 'Enter the App LB Security Group Id'),
            // string(name: 'SeconderyStorage', description: 'Enter the Secondery storage Size in GB'),
            string(name: 'ECR', description: 'Enter the image ARN of ECR'),
            string(name: 'Container_Name', description: 'Enter the container name'),
            string(name: 'Image_Tag', description: 'Enter the image tag'),
            /// string(name: 'LicenseServer', description: 'Enter the domain name of the license server'),
            booleanParam(name: 'APPLY_CHANGES', defaultValue: false, description: 'If not opted, it will be dry run')

        ]
        props << parameters(params)
        properties(props)
        whImage = docker.build("whcontainer:latest")
    }

        wrap([$class: 'BuildUser']) {
            withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: CREDENTIALS,
            roleSessionName: BUILD_USER_EMAIL]]){

            whImage.inside('-u 0:0') {
                stage ('Setup Env') {
                    script {
                        currentBuild.displayName = "#${env.BUILD_NUMBER}-${env.Account_Name}-${params.APPLY_CHANGES ? 'Apply (Create Resources)' : 'Plan (Dry Run)' }"
                        currentBuild.description = "${env.BUILD_NUMBER}-${env.Account_Name}-${params.APPLY_CHANGES ? 'Apply (Create Resources)' : 'Plan (Dry run)' }"
                    }
                        sh (script: '''
                            #!/bin/bash
                            chmod 755 -R terraform
                            
                        ''')
                }

                stage ('Validate Params') {
                    sh (script: '''
                        #!/bin/bash
                        cd ./terraform/utility
                        chmod 755 paramsValidator.sh
                        ./paramsValidator.sh "Account_Name, Tieto_ENV_Name, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, Region, Instance_Type, AMI, LB_Schema, KeyName, ECR, Image_Tag, Container_Name, APPLY_CHANGES"

                        
                    ''')
                }

                stage("collect params") {
                        sh '''
                            #!/bin/bash
                            rm -rf params.yaml
                            export AccountName=${Account_Name}
                            export TietoENVName=${Tieto_ENV_Name}
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} 
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export REGION=${Region}
                            export instancetypePipeIT=${Instance_Type}
                            export amiPipeIT=${AMI}
                            export asgsubnets=${ASGSubnets}
                            export lbsubnets=${LBSubnets}
                            
                            export keynamePipeIT=${KeyName}
                            export appsecuritygroup=${AppSecurityGroup}
                            export applbsecuritygroup=${AppLBSecurityGroup}
                            
                            export ecr=${ECR}
                            export imagetag=${Image_Tag}
                            export containername=${Container_Name}
                            export APPLY_CHANGES=${APPLY_CHANGES}

                            MODULE=02-vpc
                            rm -f .terraform/terraform.tfstate

                            terraform init \
                            -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                            -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                            -backend-config="region=${Region}"
                            export VPC=$(terraform output aws_vpc.vpc.id)
                           
                            export vpc=$(terraform output aws_vpc.vpc.id)
                            export asgsubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            export AccountName=${Account_Name}
                            export LBSchemaPipeIT=${LB_Schema}

                            if [ "${LB_Schema}" = "internet-facing" ]
                            then
                                export lbsubnets=$(terraform output aws_subnet.public_subnet_az_1a.id),$(terraform output aws_subnet.public_subnet_az_1b.id)
                            else
                                export lbsubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            fi
                             
                           
                            
                            MODULE=05-security-groups
                            rm -f .terraform/terraform.tfstate 
                            terraform init \
                                -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                                -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                                -backend-config="region=${Region}"
                            export appsecuritygroup=$(terraform output aws_security_group.app_sg.id)

                            export applbsecuritygroup=$(terraform output aws_security_group.app_lb_sg.id)

                            python generate_CF_params.py "AccountName TietoENVName REGION instancetypePipeIT amiPipeIT vpc asgsubnets lbsubnets LBSchemaPipeIT  keynamePipeIT appsecuritygroup applbsecuritygroup ecr imagetag containername " ${BUILD_ID}
                            chmod 777 params-${BUILD_ID}.yaml    

                        '''
                    }

                
                        withAWS(region: Region){

                        stage("Deploy PipeIT App") {
                            def outputs = cfnUpdate(
                                stack: "${Account_Name}-${Tieto_ENV_Name}-app", 
                                file:'./templates/pipeit.yaml', 
                                paramsFile: "./params-${BUILD_ID}.yaml", 
                                timeoutInMinutes: 60, 
                                pollInterval: 60000,
                                onFailure: 'ROLLBACK'
                            )
                            echo "${outputs}"
                        }    

                        
                    }    

                }
            }
        }
    
}

