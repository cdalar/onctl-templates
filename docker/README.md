# Example docker deployment

## run vm + install docker

```
onctl up -n qwe -a docker/docker.sh
```

## run vm + install docker + deploy container

```
onctl up -n qwe -a docker/docker.sh -a docker/nginx.sh
```
