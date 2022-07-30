## Build

```
docker build  --platform=linux/amd64 --pull  --progress plain --build-arg SERIAL=$KINDLE_SERIAL -t calibre-convert -t 849092314432.dkr.ecr.us-east-2.amazonaws.com/calibre-convert:latest .
```

```
docker push 849092314432.dkr.ecr.us-east-2.amazonaws.com/calibre-convert:latest
```

## Test
```
docker run --platform="linux/amd64"  calibre-convert:latest python3 app.py
```
