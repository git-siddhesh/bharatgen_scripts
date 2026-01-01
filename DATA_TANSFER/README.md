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


# ✅ **All supported config flags (explained)**

## 🟦 `s3` section

Settings related to the S3 upload target.

* **`bucket` (required)**
  Name of target S3 bucket

  ```
  "17b-moe"
  ```

* **`username` (optional, default = "ADMIN")**
  Used in S3 path prefix

  Destination path becomes

  ```
  s3://<bucket>/<username>/<bucket_root>/<relative_path>
  ```

* **`source_server` (optional)**
  Used as `bucket_root`

  Special case:

  * `"yotta"` → converted to `"v1"`

  Examples:

  ```
  "yotta"
  "neysa"
  "custom-root"
  ```

* **`bucket_root_existing` (optional, default = false)**
  If `true`, script verifies destination root exists in S3
  Prevents uploads to non-existent prefix

  ```
  true | false
  ```

---

## 🟧 `transfer` section

Controls **what and how** files upload.

* **`ommitted_data_path` (optional)**
  Base path used to compute the relative S3 key
  Defaults to first existing path from:

  ```
  /projects/data
  /nfs
  /weka
  /home
  ```

* **`sources` (required)**
  List of folders/files to upload
  Can mix files & directories

* **`max_parallel_jobs` (optional, default = 32)**
  Max concurrent upload workers

* **`progress_frequency` (optional, default = 15)**
  AWS CLI progress update frequency (seconds)

* **`is_cp_recursive_only_transfer_mode` (optional, default = false)**
  Mode select:

  * `false` → uses `aws s3 sync`
  * `true` → uses `aws s3 cp --recursive`

* **`checksum_enabled` (optional, default = true)**
  Enable CRC32C checksum validation

* **`compute_size` (optional, default = true)**
  If `true` → calls `du -sb` to compute size
  (use `false` for multi-TB jobs to avoid cost)

* **`du_depth` (optional, default = 1)**
  Depth of directory walk (for metrics only)

---

## 🟨 `aws` (optional)

Only **region** is read

* **`region` (default = ap-south-1)**

AWS keys are taken from **env**, not config.

---

# 📌 **Path logic reminder**

Your upload path becomes:

```
s3://<bucket>/<username>/<bucket_root>/<relative_path_under_ommitted_data_path>
```

Example:

```
bucket = 17b-moe
username = siddhesh
source_server = yotta  → becomes v1
file = /projects/data/siddhesh/A/file.txt
ommitted_data_path = /projects/data
```

Upload path:

```
s3://17b-moe/siddhesh/v1/siddhesh/A/file.txt
```

---

# 🟢 **Minimal config (already correct)**

```json
{
  "s3": {
    "bucket": "17b-moe",
    "username": "siddhesh",
    "source_server": "yotta"
  },
  "transfer": {
    "ommitted_data_path": "/projects/data",
    "sources": [
      "/projects/data/siddhesh/AWS_S3_DATA_TRANSFER"
    ],
    "checksum_enabled": true,
    "compute_size": true
  }
}
```

---

# 🟣 **Maximal config.json (all fields included)**

```json
{
  "aws": {
    "region": "ap-south-1"
  },
  "s3": {
    "bucket": "17b-moe",
    "username": "siddhesh",
    "source_server": "yotta",
    "bucket_root_existing": false
  },
  "transfer": {
    "ommitted_data_path": "/projects/data",

    "sources": [
      "/projects/data/siddhesh/AWS_S3_DATA_TRANSFER",
      "/projects/data/siddhesh/another_dataset",
      "/projects/data/siddhesh/file.txt"
    ],

    "max_parallel_jobs": 32,
    "progress_frequency": 15,

    "is_cp_recursive_only_transfer_mode": false,

    "checksum_enabled": true,

    "compute_size": true,

    "du_depth": 1
  }
}
```

---

# 🧠 **Defaults (if missing)**

| Field                                       | Default                                             |
| ------------------------------------------- | --------------------------------------------------- |
| aws.region                                  | ap-south-1                                          |
| s3.username                                 | ADMIN                                               |
| s3.bucket_root_existing                     | false                                               |
| transfer.max_parallel_jobs                  | 32                                                  |
| transfer.progress_frequency                 | 15                                                  |
| transfer.is_cp_recursive_only_transfer_mode | false                                               |
| transfer.checksum_enabled                   | true                                                |
| transfer.compute_size                       | true                                                |
| transfer.du_depth                           | 1                                                   |
| ommitted_data_path                          | first existing of `/projects/data /nfs /weka /home` |

---

# 🟩 **Recommended Real-World Settings**

### Small uploads (< 1 TB)

```
checksum_enabled = true
compute_size = true
```

### Huge uploads (multi-TB)

```
checksum_enabled = true
compute_size = false
```




