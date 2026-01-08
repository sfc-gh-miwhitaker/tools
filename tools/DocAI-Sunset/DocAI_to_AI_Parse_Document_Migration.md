# Migrating from Document AI to AI_PARSE_DOCUMENT and AI_EXTRACT

## Overview

Snowflake is deprecating **[Document AI](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/overview)** (DocAI) and transitioning to two successor functions:
- **[AI_PARSE_DOCUMENT](https://docs.snowflake.com/en/sql-reference/functions/ai_parse_document)** - For document parsing and text extraction with layout preservation
- **[AI_EXTRACT](https://docs.snowflake.com/en/sql-reference/functions/ai_extract)** - For structured data extraction from documents

**Important Deadline**: Document AI will be decommissioned on **February 28, 2026**.

---

## Key Differences

| Feature | Document AI (Deprecated) | AI_PARSE_DOCUMENT | AI_EXTRACT |
|---------|-------------------------|-------------------|------------|
| Model | Arctic-TILT (fine-tunable) | Managed AI models | arctic-extract |
| UI Required | Yes (Snowsight) | No | No |
| Fine-tuning | Supported | Not supported | Not supported |
| Setup | Multi-step (create model build, train, publish) | Single SQL call | Single SQL call |
| Primary Use | Structured extraction with custom models | Text/layout extraction, RAG pipelines | Entity/table extraction |
| Output | Custom entities per model | Markdown with preserved structure | JSON with extracted values |

---

## Migration Path

### Option 1: Continue Using Existing DocAI Models

If you have trained Document AI models you want to preserve:

1. **Migrate models to [Model Registry](https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry/overview)** (before Feb 28, 2026)
   - Go to Document AI UI in Snowsight
   - Follow the integration banner instructions to migrate models

2. **Update inference calls** from `PREDICT` to `AI_EXTRACT`:

**Before (Document AI):**
```sql
SELECT my_db.my_schema.my_model!PREDICT(
  GET_PRESIGNED_URL('@my_stage', 'document.pdf'),
  1  -- page number
);
```

**After ([AI_EXTRACT with legacy model](https://docs.snowflake.com/en/sql-reference/functions/ai_extract-document-ai)):**
```sql
SELECT AI_EXTRACT(
  model => 'my_db.my_schema.my_model',
  file => TO_FILE('@my_stage', 'document.pdf'),
  responseFormat => []
);
```

3. **[Export model builds](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/model-build-export)** (recommended)
   - Export documents, prompts, and annotations to an internal stage for backup

---

### Option 2: Migrate to AI_PARSE_DOCUMENT (Recommended for RAG/Text Extraction)

Use AI_PARSE_DOCUMENT when you need:
- Full document text extraction with layout preservation
- Markdown output for RAG pipelines
- Table structure preservation
- Multi-page document processing

**LAYOUT Mode (recommended for most use cases):**
```sql
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@my_stage', 'document.pdf'),
  {'mode': 'LAYOUT', 'page_split': true}
) AS parsed_content;
```

**OCR Mode (for scanned documents):**
```sql
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@my_stage', 'scanned_document.pdf'),
  {'mode': 'OCR'}
) AS ocr_content;
```

**Process specific pages:**
```sql
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@my_stage', 'large_document.pdf'),
  {'mode': 'LAYOUT', 'page_filter': [{'start': 0, 'end': 5}]}
);
```

---

### Option 3: Migrate to AI_EXTRACT (Recommended for Structured Extraction)

Use AI_EXTRACT when you need:
- Entity extraction (names, dates, amounts)
- Table extraction
- Structured JSON output
- No model training required

**Simple extraction:**
```sql
SELECT AI_EXTRACT(
  file => TO_FILE('@my_stage', 'invoice.pdf'),
  responseFormat => {
    'vendor_name': 'What is the vendor name?',
    'invoice_number': 'What is the invoice number?',
    'total_amount': 'What is the total amount?'
  }
);
```

**Table extraction with JSON schema:**
```sql
SELECT AI_EXTRACT(
  file => TO_FILE('@my_stage', 'financial_report.pdf'),
  responseFormat => {
    'schema': {
      'type': 'object',
      'properties': {
        'line_items': {
          'description': 'Invoice line items table',
          'type': 'object',
          'column_ordering': ['description', 'quantity', 'price'],
          'properties': {
            'description': {'type': 'array'},
            'quantity': {'type': 'array'},
            'price': {'type': 'array'}
          }
        },
        'invoice_date': {
          'description': 'Invoice date',
          'type': 'string'
        }
      }
    }
  }
);
```

**Batch processing:**
```sql
SELECT
  relative_path,
  AI_EXTRACT(
    file => TO_FILE('@my_stage', relative_path),
    responseFormat => ['document_type', 'document_date', 'key_parties']
  )
FROM DIRECTORY(@my_stage);
```

---

## Feature Comparison

### AI_PARSE_DOCUMENT Specifications

| Specification | Value |
|--------------|-------|
| Max file size | 100 MB |
| Max pages | 500 |
| Max resolution | 10000 x 10000 pixels |
| Supported formats | PDF, PPTX, DOCX, JPEG, PNG, TIFF, HTML, TXT |
| Output format | JSON with Markdown content |

### AI_EXTRACT Specifications

| Specification | Value |
|--------------|-------|
| Max file size | 100 MB |
| Max pages | 125 |
| Max entity questions | 100 per call |
| Max table questions | 10 per call |
| Max output tokens | 512 (entity), 4096 (table) |
| Supported formats | PDF, PNG, PPTX, EML, DOC/DOCX, JPEG, HTML, TXT, TIFF, BMP, GIF, WEBP, MD |

---

## Cost Considerations

| Product | Billing Model |
|---------|--------------|
| Document AI | Compute time-based |
| AI_PARSE_DOCUMENT | Per-page |
| AI_EXTRACT | Token-based |

For AI_EXTRACT with legacy Document AI models:
- Entity extraction: billed as `arctic-tilt-entity`
- Table extraction: billed as `arctic-tilt-table`

---

## Required Actions Before February 28, 2026

1. **Migrate existing models** to Snowflake Model Registry via Document AI UI
2. **Update SQL pipelines** to use `AI_EXTRACT` instead of `PREDICT` method
3. **Export model builds** to preserve training data and annotations
4. **Test new functions** in development environment before production cutover

---

## Regional Availability

Both AI_PARSE_DOCUMENT and AI_EXTRACT support [cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference). Native availability includes:

**AWS:** US West 2, US East 1, US East (Ohio), EU (Ireland), EU (Frankfurt), Asia Pacific (Sydney, Tokyo)

**Azure:** East US 2, West US 2, Europe (Netherlands)

**GCP:** US Central 1 (Iowa)

---

## Access Control

Grant the [required database role](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-llm-rest-api#required-privileges) to users:
```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE my_role;
```

---

## Additional Resources

- [AI_PARSE_DOCUMENT User Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/parse-document)
- [AI_PARSE_DOCUMENT SQL Reference](https://docs.snowflake.com/en/sql-reference/functions/ai_parse_document)
- [AI_EXTRACT SQL Reference](https://docs.snowflake.com/en/sql-reference/functions/ai_extract)
- [AI_EXTRACT for Legacy Document AI Models](https://docs.snowflake.com/en/sql-reference/functions/ai_extract-document-ai)
- [Document AI Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/overview)
- [Document AI Decommission Notice (BCR-2156)](https://docs.snowflake.com/en/release-notes/bcr-bundles/un-bundled/bcr-2156)
- [Exporting Document AI Model Builds](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/model-build-export)
- [Copying Document AI Models Between Accounts](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/copy-models)
- [Snowflake Model Registry](https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry/overview)
- [Cross-Region Inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference)
- [Cortex AI Functions Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
