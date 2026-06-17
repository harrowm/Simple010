# fetch-datasheet

Find and download a component datasheet, saving it to `design/datasheets/`.

## Usage

```
/fetch-datasheet <part-number> [lcsc=CXXXXXX] [mouser=XXX-YYYYY]
```

Examples:
```
/fetch-datasheet MC68010P
/fetch-datasheet AS6C4008-55PCN lcsc=C62646
/fetch-datasheet ATF1508AS-15JU84 mouser=556-AF1508AS15JU84
```

## What this skill does

1. Search for the datasheet PDF for the given part number.
2. Identify the canonical manufacturer part number and a direct PDF URL.
3. Download the PDF to `design/datasheets/<PartNumber>.pdf`.
4. Report the LCSC number (for JLCPCB) and Mouser part number if not already supplied.

## Instructions

When invoked, you are finding and downloading a component datasheet. Follow these steps:

### 1. Search for the datasheet

Use WebSearch with queries like:
- `"<part-number>" datasheet filetype:pdf site:datasheets.com OR site:alldatasheet.com OR site:mouser.com OR site:lcsc.com`
- `"<part-number>" datasheet pdf`

Also try manufacturer websites directly:
- Microchip/Atmel parts → microchip.com
- Motorola/Freescale/NXP parts → nxp.com
- Alliance Memory → alliancememory.com or issi.com
- Microchip (MCP) → microchip.com
- STMicroelectronics → st.com
- Texas Instruments → ti.com

### 2. Find a direct PDF URL

Look for a direct `.pdf` link in search results. Prefer:
1. Manufacturer's own website
2. Mouser product page (often has a direct datasheet link)
3. LCSC product page
4. datasheetarchive.com, alldatasheet.com, or similar

Use WebFetch to fetch a product page if needed to find the PDF URL. Look for links ending in `.pdf` or datasheet download buttons.

### 3. Download the PDF

Use Bash with curl to download:
```bash
curl -L -o "design/datasheets/<PartNumber>.pdf" "<pdf-url>"
```

Use the canonical part number (without speed/package suffixes where reasonable) as the filename. For example:
- `MC68010P` → `MC68010P.pdf`
- `AS6C4008-55PCN` → `AS6C4008.pdf`
- `ATF1508AS-15JU84` → `ATF1508AS.pdf`

Verify the download succeeded and is a PDF (not an HTML error page):
```bash
file design/datasheets/<PartNumber>.pdf | grep -i pdf
```

### 4. Report LCSC and Mouser numbers

After downloading, report:
- The filename saved
- LCSC part number (C-prefixed number from lcsc.com or jlcpcb.com) — search if not supplied
- Mouser part number (from mouser.com) — search if not supplied
- Direct manufacturer datasheet URL for reference

If you cannot find a direct PDF download, report the best datasheet URL found and explain why the download failed.
