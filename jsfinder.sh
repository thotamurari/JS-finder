#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# Setup
mkdir -p js_dump
> results.json
echo -e "${CYAN}[+] Starting Enhanced JS Secret Scanner...${NC}"

# Check input file
if [ ! -f js.txt ]; then
  echo -e "${RED}[-] js.txt file not found!${NC}"
  exit 1
fi

# Regex rules mapped to services
declare -A regex_patterns
regex_patterns["Google_API"]="AIza[0-9A-Za-z\\-_]{35}"
regex_patterns["Firebase"]="AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{140}"
regex_patterns["Mailgun"]="key-[0-9a-zA-Z]{32}"
regex_patterns["Stripe"]="sk_live_[0-9a-zA-Z]{24}"
regex_patterns["AWS_Secret"]="(?i)aws(.{0,20})?(secret|key)[\"'\\s:=]{0,10}[A-Za-z0-9/+=]{40}"
regex_patterns["Generic_Token"]="(api[-]?key|secret|token|auth|bearer|authorization)[\"'\\s:=]{0,10}[\"'A-Za-z0-9\-]{10,}"

# Read each JS URL
while read -r url; do
  echo -e "${YELLOW}[*] Fetching: $url${NC}"
  filename=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
  filepath="js_dump/$filename.js"

  curl -s "$url" -o "$filepath"

  if [ ! -s "$filepath" ]; then
    echo -e "${RED}[-] Failed or empty: $url${NC}"
    continue
  fi

  echo -e "${GREEN}[✓] Downloaded: $filename.js${NC}"
  echo -e "${CYAN}[*] Scanning $filename.js...${NC}"

  found_any=false

  for name in "${!regex_patterns[@]}"; do
    regex="${regex_patterns[$name]}"
    matches=$(grep -aoE "$regex" "$filepath")

    if [ -n "$matches" ]; then
      found_any=true
      echo -e "${RED}[!] ${MAGENTA}${name}${NC} ${RED}detected:${NC}"
      echo "$matches" | while read -r key; do
        echo -e "  ${YELLOW}→ ${GREEN}${key}${NC}"

        # Save JSON result
        echo "{\"file\":\"$filename.js\",\"type\":\"$name\",\"key\":\"$key\"}" >> results.json

        # Optional validation for Google API keys
        if [[ $name == "Google_API" ]]; then
          status=$(curl -s "https://maps.googleapis.com/maps/api/geocode/json?address=New+York&key=$key" | grep -o '"error_message"\|"OK"')
          echo -e "     ${CYAN}[Validation]${NC} → $status"
        fi
      done
    fi
  done

  if [ "$found_any" = false ]; then
    echo -e "${GREEN}[✓] No secrets found in $filename.js${NC}"
  fi
  echo ""
done < js.txt

echo -e "${CYAN}[✓] Scan Complete.${NC} Results saved to ${YELLOW}results.json${NC}"
