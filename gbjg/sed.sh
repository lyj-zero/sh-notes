#!/bin/bash
sed 's/<\/tr>/\n/g' 600/600000.html | sed 's/<[^>]*>/ /g' - >6000001
