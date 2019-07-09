[
  {
    "Name": "grafana",
    "Image": "grafana/grafana",
    "Essential": true,
    "PortMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "Environment": [
      {
        "Name": "GF_DATABASE_TYPE",
        "Value": "postgres"
      },
      {
        "Name": "GF_DATABASE_HOST",
        "Value": ${databaseUrl}
      },
      {
        "Name": "GF_DATABASE_USER",
        "Value": "grafanatest"
      },
      {
        "Name": "GF_DATABASE_PASSWORD",
        "Value": "grafana-test123"
      },
      {
        "Name": "GF_DATABASE_NAME",
        "Value": "grafana"
      },
      {
        "Name": "LOAD_BALANCER_DNS",
        "Value": ${applicationDns}
      }
    ],
    "LogConfiguration": {
      "LogDriver": "awslogs",
      "Options": {
        "awslogs-region": null,
        "awslogs-group": null,
        "awslogs-stream-prefix": "grafana"
      }
    }
  }
]
