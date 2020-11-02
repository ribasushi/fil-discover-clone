## Simple Filecoin Discover drive-cloner

### To get started:

```
wget https://raw.githubusercontent.com/ribasushi/fil-discover-clone/master/fil-cloner.bash

chmod 755 fil-cloner.bash

./fil-cloner.bash {{source drive SN}}  {{destination 1 SN}}  {{destination 2 SN}}  ...

...wait for completion message, logs are auto-uploaded to s3-ap-east-1

```

NOTE: The program is specifically hard-coded to work with Seagate ST8000 only

### Recorded example of operation and an induced failure

https://imgur.com/a/zW7r2Eg