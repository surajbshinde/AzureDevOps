def notifyBuild(String buildStatus = 'STARTED') {
    buildStatus =  buildStatus ?: 'SUCCESSFUL'
    to_emails = "${env.DEFAULT_RECIPIENT}" == "null" ? '' : "${env.DEFAULT_RECIPIENT}"
    def subject = "${buildStatus}: Job '${env.JOB_NAME} :${env.BUILD_NUMBER}'"
    def summary = "${subject} (${env.BUILD_URL})"
    def details = """
        <p>${buildStatus}: Job '${env.JOB_NAME} ${env.BUILD_NUMBER}':</p>
        <p>Check console output at "<a href="${env.BUILD_URL}">${env.JOB_NAME}:${env.BUILD_NUMBER}</a>"</p>
    """

    emailext (
        subject: subject,
        body: details,
        attachLog: true,
        to: to_emails,
        recipientProviders: [
            [$class: 'RequesterRecipientProvider']
        ]
    )
}

node {
    def whImage
    try {
        stage ("Get parameters"){
            checkout scm
            List props = []
            List params = [
                string(name: 'Account_Name', description: 'Please Enter the name of the customer.'),
                string(name: 'Tieto_ENV_Name', description: 'Please Enter the env for which you want to deploy the db (ref/ci/dev) (Note: Only lowercase values allowed).'),
                choice(name: 'Region', description: 'Please select the AWS Region', choices: 'eu-west-1\neu-west-2\neu-west-3\neu-central-1\nus-west-1\nus-west-2\nus-east-2\nus-east-1\nap-northeast-1\nap-northeast-2\nap-northeast-3\nap-south-1\nap-southeast-1\nap-southeast-2\nca-central-1\ncn-north-1\ncn-northwest-1\nsa-east-1'),
                credentials(name: 'CREDENTIALS', description: 'AWS Credentials', credentialType: "Username with password"),
                string(name: "ArtefactVersion", description: "Artefact Version", defaultValue: "11.2.SP03"),
                string(name: "WildflyVersion", description: "Wildfly Version", defaultValue: "10.1.0"),
                string(name: "EarfileName", description: "Earfile Name", defaultValue: "ec-app.ear"),
                string(name: "Operation", description: "Schema Operation name"),
                string(name: "DBHostName", description: "Database Hostname"),
                string(name: "DBSID", description: "Database SID"),
                string(name: "InstanceType", description: "Application EC2 instance type", defaultValue: 't2.large'),
                string(name: "AMI", description: "AMI to use for App instances."),
                string(name: "KeyName", description: "Name of an existing EC2 KeyPair"),
                string(name: "SslCertificateARN", description: "ARN of valid  and Issued certificate"),
                string(name: "SeconderyStorageSpaceSize", description: "Secondery storage Size in GB", defaultValue: "10"),
                choice(name: "LBType", description: "Type of Application LB", choices: "internal\ninternet-facing"),
                string(name: "KmsKeyARN", description: "ARN of KMS key. Note: Key should be present in given region and CloudWatch service principal should have permission to use the CMK (more info: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html#cmk-permissions)"),
                string(name: "DatadogAPIKey", description: "API Key for Datadog agent", defaultValue: "802b730ce0b5d4c6d11f9c229b15d68b"),
                string(name: "ScriptFilename", description: "wildfly Installation script file name (this needs to be present in s3)", defaultValue: "ecdeployercustom.ps1"),
                password(name: "SchemaPassword", description: "Schema Password", defaultValue: "energy"),
                password(name: "KeyCloakPassword", description: "KeyCloak Password", defaultValue: "admin"),
                string(name: "FQDN", description: "valid url"),
                choice(name: "EncryptPassword", description: "passwords will be encrypted if checked", choices: "YES\nNO" ),
                choice(name: "SslEnabledOnProxty", description: "SSL enabled on proxy if selected YES", choices: "YES\nNO" ),
                choice(name: "PipeITDeploy", description: "PipeIT infra setup if selected YES", choices: "YES\nNO" ),
                string(name: 'Instance_Type_PipeIT', description: 'Enter the Instance type for PipeIT', defaultValue: "no"),
                string(name: 'AMI_PipeIT', description: 'Enter the AMI for PipeIt setup', defaultValue: "no"),
                choice(name: "LB_Schema_PipeIT", description: "Type of Application LB for PipeIT", choices: "no\ninternal\ninternet-facing"),
                string(name: 'KeyName_PipeIT', description: 'Enter the Key name for PipeIT', defaultValue: "no"),
               // string(name: 'SeconderyStorage_PipeIT', description: 'Enter the Secondery storage Size in GB', defaultValue: "no"),
                string(name: 'ECR', description: 'Enter the image ARN of ECR', defaultValue: "no"),
                string(name: 'Container_Name', description: 'Enter the container name', defaultValue: "no"),
                string(name: 'Image_Tag', description: 'Enter the image tag', defaultValue: "no"),
                booleanParam(name: 'APPLY_CHANGES', defaultValue: false, description: 'If not opted, it will be dry run')
                // templates4567890-    
            ]
            props << parameters(params)
            properties(props)
            whImage = docker.build("whcontainer:${env.BUILD_ID}")
        }
        
        whImage.inside {
            wrap([$class: 'BuildUser']) {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: CREDENTIALS,
                    roleSessionName: BUILD_USER_EMAIL]]) {

                    stage ('Setup Env') {
                        script {
                            currentBuild.displayName = "#${env.BUILD_NUMBER}-${env.Account_Name}-deployApp"
                            currentBuild.description = "${env.BUILD_NUMBER}-${env.Account_Name}-deployApp"
                        }

                        sh (script: '''
                            #!/bin/bash
                            chmod 755 -R terraform
                        ''')
                    }

                    stage ('Validate Params for App Deploy') {
                        sh (script: '''
                            #!/bin/bash
                            cd ./terraform/utility
                            chmod 755 paramsValidator.sh
                            ./paramsValidator.sh "Account_Name, Tieto_ENV_Name, Region, CREDENTIALS, ArtefactVersion, WildflyVersion, EarfileName, Operation, DBHostName, DBSID, InstanceType, AMI, KeyName, SeconderyStorageSpaceSize, LBType, KmsKeyARN, DatadogAPIKey, ScriptFilename, SchemaPassword, FQDN, KeyCloakPassword, EncryptPassword, SslEnabledOnProxty"
                        ''')
                    }

                    stage ('Validate Params for PipeIT Deploy') {
                        sh (script: '''
                            #!/bin/bash
                            cd ./terraform/utility
                            chmod 755 paramsValidatorpipeit.sh
                            ./paramsValidatorpipeit.sh "Account_Name, Tieto_ENV_Name, Region, CREDENTIALS, Instance_Type_PipeIT, AMI_PipeIT, LB_Schema_PipeIT, KeyName_PipeIT, ECR, Container_Name, Image_Tag "
                        ''')
                    }


                    stage("Setup Log group"){
                        sh '''
                            #!/bin/bash
                            for logGroupName in /aws/ec2/${Account_Name}-${Tieto_ENV_Name}-app;
                                    do
                                        awsLogGroupName=$(aws logs describe-log-groups --log-group-name-prefix ${logGroupName} --query logGroups[0].logGroupName --output text --region ${Region})
                                        if [ "${logGroupName}" = "${awsLogGroupName}" ]
                                        then
                                            echo "Log group ${logGroupName} is already present"
                                        else
                                            echo "creating log group"
                                            aws logs create-log-group --log-group-name ${logGroupName} --region ${Region}
                                        fi
                                        echo "associate log group with KMS"
                                        aws logs associate-kms-key --log-group-name ${logGroupName} --kms-key-id ${KmsKeyARN} --region ${Region}
                                    done
                            '''
                        }

                    stage("collect params for app deploy") {
                        sh '''
                            #!/bin/bash
                            rm -rf params.yaml
                            export AccountName=${Account_Name}

                            MODULE=02-vpc
                            rm -f .terraform/terraform.tfstate 

                            if [ "${EnableProxy}" = "YES" ]
                            then
                                if [ "${SslEnabledOnProxty}" = "YES" ]
                                then
                                    export LBForwardToPort=443
                                    export LBForwardToProtocol=HTTPS
                                else
                                    export LBForwardToPort=80
                                    export LBForwardToProtocol=HTTP
                                fi
                                export WildflyPort=8443
                                export WildflyProtocol=HTTPS
                            else
                                export LBForwardToPort=443
                                export WildflyPort=443
                                export WildflyProtocol=HTTPS
                                export LBForwardToProtocol=HTTPS
                            fi

                            terraform init \
                            -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                            -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                            -backend-config="region=${Region}"
                            export VPC=$(terraform output aws_vpc.vpc.id)
                            export vpc=$(terraform output aws_vpc.vpc.id)
                            export ASGSubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            export AccountName=${Account_Name}
                            export LBSchema=${LBType}

                            if [ "${LBType}" = "internet-facing" ]
                            then
                                export LBSubnets=$(terraform output aws_subnet.public_subnet_az_1a.id),$(terraform output aws_subnet.public_subnet_az_1b.id)
                            else
                                export LBSubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            fi


                            MODULE=05-security-groups
                            rm -f .terraform/terraform.tfstate 
                            terraform init \
                                -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                                -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                                -backend-config="region=${Region}"
                            export AppSecurityGroup=$(terraform output aws_security_group.app_sg.id)

                            export AppLBSecurityGroup=$(terraform output aws_security_group.app_lb_sg.id)
                            export EnvName=${Tieto_ENV_Name}

                            export AccountName=${Account_Name}
                            export TietoENVName=${Tieto_ENV_Name}
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} 
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export REGION=${Region}
                            export Instance_Type=${InstanceType}
                            export ami=${AMI}
                            export vpc=${VPC}
                            export asgsubnets=${ASGSubnets}
                            export lbsubnets=${LBSubnets}
                            export keyname=${KeyName}
                            export appsecuritygroup=${AppSecurityGroup}
                            export applbsecuritygroup=${AppLBSecurityGroup}
                            export seconderystorage=${SeconderyStorage}
                            python generate_CF_params.py "ArtefactVersion WildflyVersion EarfileName SslCertificateARN EnvName AccountName LBSchema Operation DBHostName DBSID InstanceType AMI VPC ASGSubnets LBSubnets KeyName SeconderyStorageSpaceSize DatadogAPIKey ScriptFilename AppSecurityGroup AppLBSecurityGroup EncryptPassword SchemaPassword FQDN KeyCloakPassword LBForwardToPort LBForwardToProtocol WildflyPort WildflyProtocol " ${BUILD_ID}
                            chmod 777 params-${BUILD_ID}.yaml
                            cat params-${BUILD_ID}.yaml
                        '''
                    }


                    stage("collect params for pipeit") {
                        sh '''
                            #!/bin/bash
                            rm -rf params.yaml

                            export AccountName=${Account_Name}

                            MODULE=02-vpc
                            rm -f .terraform/terraform.tfstate 

                            terraform init \
                            -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                            -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                            -backend-config="region=${Region}"
                            export VPC=$(terraform output aws_vpc.vpc.id)
                            
                            export vpc=$(terraform output aws_vpc.vpc.id)
                            export ASGSubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            export LBSchemaPipeIT=${LB_Schema_PipeIT}

                            if [ "${LB_Schema_PipeIT}" = "internet-facing" ]
                            then
                                export LBSubnets=$(terraform output aws_subnet.public_subnet_az_1a.id),$(terraform output aws_subnet.public_subnet_az_1b.id)
                            else
                                export LBSubnets=$(terraform output aws_subnet.private_subnet_az_1a.id),$(terraform output aws_subnet.private_subnet_az_1b.id)
                            fi

                            MODULE=05-security-groups
                            rm -f .terraform/terraform.tfstate 
                            terraform init \
                                -backend-config="bucket=tieto-${Account_Name}-tfstate" \
                                -backend-config="key=env/${Region}/${Account_Name}/00-Infra-Layout/${MODULE}/terraform.tfstate" \
                                -backend-config="region=${Region}"
                            export AppSecurityGroup=$(terraform output aws_security_group.app_sg.id)
                            export AppLBSecurityGroup=$(terraform output aws_security_group.app_lb_sg.id)
                            export TietoENVName=${Tieto_ENV_Name}
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} 
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export REGION=${Region}
                            export asgsubnets=${ASGSubnets}
                            export lbsubnets=${LBSubnets}
                            export appsecuritygroup=${AppSecurityGroup}
                            export applbsecuritygroup=${AppLBSecurityGroup}
                            export instancetypePipeIT=${Instance_Type_PipeIT}
                            export amiPipeIT=${AMI_PipeIT}

                            export ecr=${ECR}
                            export vpc=${VPC}
                            export imagetag=${Image_Tag}
                            
                            export containername=${Container_Name}
                            export keynamePipeIT=${KeyName_PipeIT}
                            python generate_CF_params_pipeit.py "TietoENVName asgsubnets lbsubnets appsecuritygroup applbsecuritygroup instancetypePipeIT amiPipeIT ecr imagetag  containername keynamePipeIT vpc AccountName REGION " ${BUILD_ID}
                            chmod 777 params-pipeit-${BUILD_ID}.yaml
                            cat params-pipeit-${BUILD_ID}.yaml
                        '''
                    }

                    withAWS(region: Region){ 
                        stage("Deploy EC App") {
                            def outputs = cfnUpdate(
                                stack: "${Account_Name}-${Tieto_ENV_Name}-app", 
                                file:'templates/app.yaml', 
                                paramsFile: "params-${BUILD_ID}.yaml", 
                                timeoutInMinutes: 60, 
                                pollInterval: 60000,
                                onFailure: 'ROLLBACK'
                            )
                            echo "${outputs}"
                        }
                      
                        stage("Add HTTP Listner"){
                            sh (script: '''
                                export LB_ARN=$(aws cloudformation --region ${Region} describe-stacks --stack ${Account_Name}-${Tieto_ENV_Name}-app --query "Stacks[0].Outputs[?OutputKey=='AppLbArn'].OutputValue" --output text)
                                python boto3Scripts/createListener80ForApp.py ${Account_Name}-${Tieto_ENV_Name}-app ${Region}
                            ''')
                        }

                        stage("Add DNS (Route53) Entry"){
                            sh (script: '''
                                #!/bin/bash
                                rm -f .terraform/terraform.tfstate
                                export HOSTED_ZONE_TYPE=public
                                if [ "${Tieto_ENV_Name}" = "prd" ]
                                then
                                    export RECORD_SET_NAME=app
                                else
                                    export RECORD_SET_NAME=${Tieto_ENV_Name}.app
                                fi
                                export RECORD_SET_RECORD=$(aws cloudformation --region ${Region} describe-stacks --stack ${Account_Name}-${Tieto_ENV_Name}-app --query "Stacks[0].Outputs[?OutputKey=='AppDNS'].OutputValue" --output text)
                                export REGION=${Region}
                                export MODULE=utility/misc/record_set_cname
                                export ACCOUNT_NAME=${Account_Name}
                                export APPLY_CHANGES=true
                                export TIETO_ENV_NAME=${Tieto_ENV_Name}
                                cd ./terraform/${MODULE}/ci

                                #Modifing Module so it points to correct S3 key
                                export MODULE=${MODULE}/${ACCOUNT_NAME}/${TIETO_ENV_NAME}/${RECORD_SET_NAME}
                                ./run.sh
                            ''')
                        }
                     
                        stage("Deploy pipeIT App") {
                            if (env.PipeITDeploy == "YES") {
                                def outputs = cfnUpdate(
                                    stack: "${Account_Name}-${Tieto_ENV_Name}-pipeIT-app", 
                                    file:'./templates/pipeit.yaml', 
                                    paramsFile: "./params-pipeit-${BUILD_ID}.yaml", 
                                    timeoutInMinutes: 60, 
                                    pollInterval: 60000,
                                    onFailure: 'ROLLBACK'
                                )
                                echo "${outputs}"
                            }
                            else
                                echo "ignore"     
                        }
                    }
                }
            }
        }
    }catch (e) {
        currentBuild.result = "FAILED"
        throw e
    }
    finally {
        stage("Send Notifications"){
            notifyBuild(currentBuild.result)
        }
    }
}
