def call(Map config) {
    def serviceName = config.serviceName
    def dockerRegistry = config.dockerRegistry ?: env.DOCKER_REGISTRY
    def environment = config.environment ?: 'dev'
    def skipTests = config.skipTests ?: false
    def deploy = config.deploy ?: true

    pipeline {
        agent any

        environment {
            SERVICE_NAME = "${serviceName}"
            DOCKER_REGISTRY = "${dockerRegistry}"
            GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
            VERSION = "${env.BUILD_NUMBER}-${GIT_COMMIT_SHORT}"
        }

        stages {
            stage('Build') {
                steps {
                    dir("services/${SERVICE_NAME}") {
                        sh '''
                            chmod +x mvnw
                            ./mvnw clean compile -DskipTests -B
                        '''
                    }
                }
            }

            stage('Test') {
                when {
                    expression { !skipTests }
                }
                steps {
                    dir("services/${SERVICE_NAME}") {
                        sh './mvnw test -B'
                    }
                }
                post {
                    always {
                        junit "services/${SERVICE_NAME}/target/surefire-reports/*.xml"
                    }
                }
            }

            stage('Package') {
                steps {
                    dir("services/${SERVICE_NAME}") {
                        sh './mvnw package -DskipTests -B'
                    }
                }
            }

            stage('Docker Build & Push') {
                steps {
                    dir("services/${SERVICE_NAME}") {
                        script {
                            docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-registry-credentials') {
                                def image = docker.build("${DOCKER_REGISTRY}/${SERVICE_NAME}:${VERSION}")
                                image.push()
                                image.push(environment)
                            }
                        }
                    }
                }
            }

            stage('Helm Deploy') {
                when {
                    expression { deploy }
                }
                steps {
                    dir("helm/charts/${SERVICE_NAME}") {
                        sh """
                            helm upgrade --install ${SERVICE_NAME} . \
                                --namespace mobile-banking-${environment} \
                                -f values-${environment}.yaml \
                                --set image.tag=${VERSION} \
                                --wait \
                                --timeout 5m
                        """
                    }
                }
            }
        }

        post {
            always {
                cleanWs()
            }
        }
    }
}
