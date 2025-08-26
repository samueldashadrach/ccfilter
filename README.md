2025-08-25

# README

Disclaimer
 - Might not be updated

Bash and Perl pipeline to filter entire commoncrawl based on a static list of urls. Tested successfully.

url list supplied **must not** contain http, https, www, terminating slash

#### How to run

OPTIONAL: download fresh copy of datasets
```
cd ccfilter/urls

mkdir data/ && wget -qO- https://www.domcop.com/files/top/top10milliondomains.csv.zip | funzip | awk -F'","' 'NR>1{print $2} NR==1001{exit}' > top1000.txt

for p in {1..165}; do curl -sL "https://searchmysite.net/search/browse/?page=$p" | htmlq -a href 'table.sms-browse tbody tr.search-result .result-title > a[href^="http"]'; done | sed -E 's#^https?://##; s#/$##' > searchmysite.txt

curl -fsSL 'https://raw.githubusercontent.com/kevquirk/512kb.club/refs/heads/main/_data/sites.yml' | sed -nE 's/^[[:space:]]*-[[:space:]]*domain:[[:space:]]+(www\.)?([^[:space:]]+).*$/\2/p' > 512kb.txt

{cat fewforums.txt && cat social.txt && cat searchmysite.txt && cat 512kb.txt } >> final.txt
```

```
sudo apt install parallel -y && sudo apt install cpanminus -y && cpanm Regexp::Assemble && mkdir s5/ && wget -qO- https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz | tar -xzf - -C s5/

# assumes 32 threads
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

#### Benchmarks (Bad estimates)

using Hetzner AMD Ryzen threadripper 2950X 32 threads
 - fewforums2.txt (old version)
   - data out/in = 275 MB out / (500 * 60 MB in) = 0.009
   - estimated data out = 0.009 * 800 TB = 7.2 TB
   - estimated time = 1d 4h / snap
 - top100.txt
   - data out/in = 466 MB out / (500 * 60 MB in) = 0.016
   - estimated time = 1d 4h / snap
 - top1k.txt
   - data out/in = 1.9 GB / (500 * 60 MB in) = 0.063
   - estimated time = 1d 4h / snap
 - top10k.txt
   - data out/in = 6 GB / (533 * 60 MB in) = 0.19
   - estimated time = 1d 4h / snap
 - social.txt
   - data out/in = 216 MB / (578 * 60 MB in) = 0.006
   - estimated time = 1d 4h / snap
 - final.txt (contains fewforums.txt, social.txt, searchmysite.txt, 512kb.txt)
   - data out/in = 551 MB / (508 * 60 MB in) = 0.018
   - estimated data out = 0.018 * 800 TB = 14.4 TB
   - estimated time = 1d 4h / snap
 - libgen, annas archive not found in commoncrawl, checked using ccfilter, and also checked at: https://index.commoncrawl.org


in general
 - estimated time = ~1 day/snap => estimated cost = ~1 day/snap * $100/mo * 115 snaps = ~$115
 - estimated data out = 800 TB * data out/in

theoretical optimal
 - single machine
   - estimated time = 800 TB / (0.1 GB/s) = 3 months
 - parallelise across enough machines
   - estimated time = 0


