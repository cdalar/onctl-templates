# Test template

Use this template to validate environment variables passed to your VM:

```
onctl up -n test -a test/test.sh -e TEST_VAR=hello
```

The script echoes the `TEST_VAR` value along with the public IP so you can confirm parameter injection.
