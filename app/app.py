#!/usr/bin/env python

import os
import json
import subprocess
import urllib.parse

import boto3


s3 = boto3.client('s3')
secrets = boto3.client('secretsmanager',region_name='us-east-2')

tmp_azw3 = "/tmp/ebook.azw3"
tmp_epub = "/tmp/ebook.epub"
epub_bucket = "epub-output"
remark_token_id = "remarkable-token"

rmapi_config = "/tmp/rmapi.conf"
rmapi_cache = "/tmp/cache/"

def lambda_handler(event, context):
    remark_secret = secrets.get_secret_value(
        SecretId=remark_token_id
    )
    tokens = json.loads(remark_secret["SecretString"])
    with open(rmapi_config, 'w') as f:
        f.write(f"devicetoken: {tokens['devicetoken']}\n")
        f.write(f"usertoken: {tokens['usertoken']}\n")

    event_type = event ['Records'][0]['eventName']
    if (event_type != "ObjectCreated:Put"):
        raise Exception(f"Expected 'ObjectCreated:Put' event, got {event_type}")

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        s3.download_file(Bucket=bucket, Key=key, Filename=tmp_azw3)
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e

    convert(tmp_azw3, tmp_epub)

    filename, _ = os.path.splitext(key)

    s3.upload_file(tmp_epub, epub_bucket, filename + '.epub')

    subprocess.run([
        "rmapi",
         "put",
         tmp_epub,
         filename + '.epub',
    ],
        env=dict(
            os.environ,
            RMAPI_CONFIG=rmapi_config,
            XDG_CACHE_HOME=rmapi_cache,
        ),
        check=True
    )

    return {
        'statusCode': 200,
        'body': json.dumps(f"Converted and uploaded {filename}")
    }

def convert(azw3_file, epub_out):
    print("Running: " + " ".join([
        "ebook-convert",
        azw3_file,
        epub_out,
    ]))
    subprocess.run([
        "ebook-convert",
        azw3_file,
        epub_out,
    ])

if __name__ == "__main__":
    send_to_remarkable()

