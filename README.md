## Build

```
docker build  --platform=linux/amd64 --pull  --progress plain --build-arg SERIAL=$KINDLE_SERIAL -t calibre-convert -t 849092314432.dkr.ecr.us-east-2.amazonaws.com/calibre-convert:latest .
```

```
docker push 849092314432.dkr.ecr.us-east-2.amazonaws.com/calibre-convert:latest
```

Login
```
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 849092314432.dkr.ecr.us-east-2.amazonaws.com
```

## Test
```
docker run --platform="linux/amd64"  calibre-convert:latest python3 app.py
```

(comment out ENTRYPOINT in Dockerfile)

## AWS
User: harrington.dave+remark@gmail.com

https://us-east-2.console.aws.amazon.com/lambda/home?region=us-east-2#/functions/calibre-conversion?tab=testing
