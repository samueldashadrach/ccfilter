2025-08-25

# README

Disclaimer
 - Might not be updated

Bash and Perl pipeline to filter entire commoncrawl based on a static list of urls. Tested successfully.

url list supplied **must not** contain http, https, www, terminating slash

#### How to run

OPTIONAL: download datasets
```
cd ccfilter/urls

mkdir data/ && wget -qO- https://www.domcop.com/files/top/top10milliondomains.csv.zip | funzip | awk -F'","' 'NR>1{print $2} NR==1001{exit}' > top1000.txt

for p in {1..165}; do curl -sL "https://searchmysite.net/search/browse/?page=$p" | htmlq -a href 'table.sms-browse tbody tr.search-result .result-title > a[href^="http"]'; done | sed -E 's#^https?://##; s#/$##' > searchmysite.txt

curl -fsSL 'https://raw.githubusercontent.com/kevquirk/512kb.club/refs/heads/main/_data/sites.yml' | sed -nE 's/^[[:space:]]*-[[:space:]]*domain:[[:space:]]+(www\.)?([^[:space:]]+).*$/\2/p' > 512kb.txt

{cat fewforums.txt && cat social.txt && cat searchmysite.txt && cat 512kb.txt } >> final.txt
```

```
# install dependencies
sudo apt install parallel -y && sudo apt install cpanminus -y && cpanm Regexp::Assemble && mkdir s5/ && wget -qO- https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz | tar -xzf - -C s5/

# OPTIONAL: dry run
s5/s5cmd ls 's3://commoncrawl/crawl-data/CC-MAIN-2025-33/segments/*/wet/*.warc.wet.gz' | awk '{print $NF}'

# download, process, store (CPU-bottlenecked, 32 threads)
s5/s5cmd ls 's3://commoncrawl/crawl-data/CC-MAIN-2025-33/segments/*/wet/*.warc.wet.gz' > paths.txt
cat paths.txt | awk '{print $NF}' | parallel -j32 --bar --group 'mkdir -p data/{//} && s5/s5cmd cat s3://commoncrawl/crawl-data/CC-MAIN-2025-33/segments/{} | zcat | ccfilter/filter.pl ccfilter/urls/top1k.txt > data/{.}'
```

#### Why filter?

full data (compressed) is 800 TB, can filter using this script, before further processing for your use case

regex below includes CC-MAIN-2013-20 to CC-MAIN-2025-33 (both inclusive), excludes CC-MAIN-2008-2009, CC-MAIN-2009-2010, CC-MAIN-2012

```
root@ubuntu-8gb-fsn1-1:~# s5/s5cmd du "s3://commoncrawl/crawl-data/CC-MAIN-20??-??/segments/*/wet/*"
896855474262727 bytes in 7216667 objects: s3://commoncrawl/crawl-data/CC-MAIN-20??-??/segments/*/wet/*
```