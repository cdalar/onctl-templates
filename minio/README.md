# MinIO setup options

Use Docker for a quick S3-compatible server:

```
onctl up -n minio -a minio/docker.sh
```

For a native installation using the official Debian package instead:

```
onctl up -n minio -a minio/minio.sh
```

Both scripts expose the MinIO API on port `9000` and the console on port `9001`.
