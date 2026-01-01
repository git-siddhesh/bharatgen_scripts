# Build the docker image: 

> Already build in your system:

`docker build --network host --no-cache -t s3-transfer-cli:v6  -f Dockerfile .`

Verify the build:

`docker images | grep s3-transfer-cli`

---



- Provide you structured logs
- Log every 15 sec
- Transfer data in structure directory structure 
	
```
<bucket-name>/username/<yotta/neysa>/<coping folder>
```


## Check for the docker image
```
docker images:
```
```
 s3-transfer-cli     v6                 7426023d5782   5 minutes ago       310MB
```


# Create a config file 
`config-siddhesh.json`
```
{
    "s3": {
        "bucket": "17b-moe",
        "username": "siddhesh",
        "source_server": "yotta"
    },
    "transfer": {
        "ommitted_data_path": "/projects/data",
        "sources": [
            "/projects/data/siddhesh/S3_TRANSFER_CLI/results",
            "/projects/data/siddhesh/S3_TRANSFER_CLI/results copy"
        ],
        "checksum_enabled": true,
        "compute_size": true
    }
}
```


# Buckets: 
## Mounted Buckets: 
- 17b-moe 
- bg-speech-data 

## Team specific buckets: 
- bgen-data-team 
- bgen-posttraining-team 
- bgen-pretraining-team 
- bgen-vision-team

# Source_server:
- yotta
- neysa

# Ommitted_data_path:
- /projects/data
- /weka
- /nfs
- /home

# Compute_size: 
- `true`: if transfer data is small 
- `false`: if transfer data in huge [in multi-TBs]


# Run command: 
```
docker run -dit --network host --dns 8.8.8.8 -v $PWD:/app -v /projects/data:/projects/data s3-transfer-cli:v6 config-siddhesh.json
```


## Optional args:
- --network
- --dns 

## Data path mounting: 

[Keep it as is on both side]
### Example:
```
/projects/data:/projects/data
/weka:/weka
/nfs:/nfs
```

## Note: 
> Config file name: config file should in pwd




# Delete the root accessed folders and files

```
docker run --rm -v /projects/data/siddhesh/S3_TRANSFER_CLI/results:/mnt   --user root   alpine:latest   rm -rf /mnt/test_run
```

# Change permission using root 

```
docker run --rm -v /projects/data/siddhesh/AGRI_FORM:/mnt   --user root   alpine:latest   chmod -R 777 /mnt
```


docker run --rm -it --network host --dns 8.8.8.8 \
  -v /projects/data:/projects/data \
  -v $PWD/config-v6.json:/app/custom_config.json \
  s3-transfer-cli:v6
