import os
import json
import logging

import boto3
import requests


logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
ssm = boto3.client("ssm")

NR_API_KEY_PARAM = os.environ["NR_API_KEY_PARAM"]
NR_POLICIES_URL = "https://api.newrelic.com/v2/alerts_policies.json"


HTTP_TIMEOUT = 5


def lambda_handler(event, context):
    logger.info(f"Event received: {event}")

    try:
        instance_id = event["detail"]["instance-id"]


        resp = ec2.describe_instances(InstanceIds=[instance_id])
        reservations = resp.get("Reservations", [])

        app_name = None
        for r in reservations:
            for i in r.get("Instances", []):
                for tag in i.get("Tags", []):
                    if tag["Key"] == "application":
                        app_name = tag["Value"]
                        break

        if not app_name:
            logger.info(f"Instance {instance_id} has no 'application' tag. Skipping.")
            return {"status": "skipped"}

        # Fetch New Relic API key from SSM
        api_key = ssm.get_parameter(
            Name=NR_API_KEY_PARAM,
            WithDecryption=True
        )["Parameter"]["Value"]

        headers = {
            "X-Api-Key": api_key,
            "Content-Type": "application/json"
        }

        # Check if policy already exists 
        existing = requests.get(
            NR_POLICIES_URL,
            headers=headers,
            timeout=HTTP_TIMEOUT
        )
        existing.raise_for_status()

        policies = existing.json().get("policies", [])
        if any(p["name"] == app_name for p in policies):
            logger.info(f"Policy already exists for '{app_name}'")
            return {"status": "exists"}

        # Create policy
        payload = {
            "policy": {
                "name": app_name,
                "incident_preference": "PER_POLICY"
            }
        }

        create_resp = requests.post(
            NR_POLICIES_URL,
            headers=headers,
            json=payload,
            timeout=HTTP_TIMEOUT
        )
        create_resp.raise_for_status()

        logger.info(f"Created New Relic policy '{app_name}'")
        return {"status": "created"}

    except Exception:
        logger.exception("Failed processing EC2 event")
        raise