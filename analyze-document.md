# Advanced Document Analysis with VNRecognizeDocumentsRequest

## Overview

This document outlines the planned implementation of advanced document understanding features using Apple's `VNRecognizeDocumentsRequest`, introduced in WWDC 2024 for macOS 15 Sequoia but **requiring macOS 26+** for production use.

## Current Limitation

**Minimum OS Requirement:** macOS 26.0+
**Current System:** macOS 15.5
**Status:** Cannot implement until OS upgrade is available

## Capabilities

`VNRecognizeDocumentsRequest` provides structured document parsing that goes far beyond basic OCR:

### 1. Table Extraction
- **Row/Column/Cell Structure**: Access tables as a structured hierarchy
- **Cell-level Content**: Each cell provides text transcript and detected data
- **Table Boundaries**: Bounding boxes for entire tables and individual cells

### 2. List Detection
- Hierarchical list structure (bullets, numbers, nested lists)
- List item identification with indentation levels
- Ordered and unordered list types

### 3. Paragraph Identification
- Proper paragraph segmentation (superior to manual coordinate sorting)
- Paragraph-level bounding boxes
- Reading order handled automatically by the framework

### 4. Automatic Data Detection
The framework automatically detects and extracts structured data:
- **Email addresses** with validation
- **Phone numbers** with formatting
- **URLs** with protocol identification
- **Dates** with parsed components
- **Measurements** (distances, weights, volumes, etc.)
- **Flight numbers** (airline codes + flight numbers)
- **Tracking numbers** (shipping carriers)
- **Addresses** (street, city, state, postal codes)
- **Money amounts** with currency codes

### 5. Language Support
- 26 languages supported
- Automatic language identification
- Multi-language document handling

### 6. Integrated Features
- Built-in barcode detection (no separate request needed)
- Document orientation detection
- Quality assessment

## Proposed API Design

### New Endpoint: `/analyze-document`

**Method:** POST
**Content-Type:** `application/octet-stream`
**Body:** Raw binary image data

### Response Schema

```json
{
  "success": true,
  "timestamp": "2025-10-17T10:30:45Z",
  "imageInfo": {
    "width": 2000,
    "height": 3000,
    "format": "PNG",
    "colorSpace": "sRGB"
  },
  "document": {
    "pages": [
      {
        "pageNumber": 1,
        "paragraphs": [
          {
            "text": "Full paragraph text here...",
            "boundingBox": { "x": 0.1, "y": 0.8, "width": 0.8, "height": 0.1 },
            "confidence": 0.98
          }
        ],
        "tables": [
          {
            "boundingBox": { "x": 0.1, "y": 0.5, "width": 0.8, "height": 0.3 },
            "rowCount": 5,
            "columnCount": 3,
            "rows": [
              {
                "cells": [
                  {
                    "text": "Product Name",
                    "boundingBox": { "x": 0.1, "y": 0.7, "width": 0.3, "height": 0.05 },
                    "rowIndex": 0,
                    "columnIndex": 0,
                    "detectedData": []
                  },
                  {
                    "text": "$49.99",
                    "boundingBox": { "x": 0.4, "y": 0.7, "width": 0.2, "height": 0.05 },
                    "rowIndex": 0,
                    "columnIndex": 1,
                    "detectedData": [
                      {
                        "type": "money",
                        "amount": 49.99,
                        "currency": "USD"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ],
        "lists": [
          {
            "type": "unordered",
            "items": [
              {
                "text": "First bullet point",
                "level": 0,
                "boundingBox": { "x": 0.1, "y": 0.4, "width": 0.7, "height": 0.03 }
              },
              {
                "text": "Nested item",
                "level": 1,
                "boundingBox": { "x": 0.15, "y": 0.37, "width": 0.65, "height": 0.03 }
              }
            ]
          }
        ],
        "detectedData": [
          {
            "type": "emailAddress",
            "text": "support@example.com",
            "emailAddress": "support@example.com",
            "boundingBox": { "x": 0.2, "y": 0.2, "width": 0.3, "height": 0.02 }
          },
          {
            "type": "phoneNumber",
            "text": "(555) 123-4567",
            "phoneNumber": "+15551234567",
            "boundingBox": { "x": 0.2, "y": 0.18, "width": 0.25, "height": 0.02 }
          },
          {
            "type": "url",
            "text": "https://example.com",
            "url": "https://example.com",
            "boundingBox": { "x": 0.2, "y": 0.16, "width": 0.3, "height": 0.02 }
          },
          {
            "type": "date",
            "text": "October 17, 2025",
            "date": "2025-10-17",
            "boundingBox": { "x": 0.7, "y": 0.9, "width": 0.2, "height": 0.02 }
          },
          {
            "type": "flightNumber",
            "text": "AA1234",
            "airline": "AA",
            "flightNumber": "1234",
            "boundingBox": { "x": 0.3, "y": 0.5, "width": 0.1, "height": 0.02 }
          },
          {
            "type": "trackingNumber",
            "text": "1Z999AA10123456784",
            "carrier": "UPS",
            "trackingNumber": "1Z999AA10123456784",
            "boundingBox": { "x": 0.3, "y": 0.3, "width": 0.4, "height": 0.02 }
          }
        ],
        "barcodes": [
          {
            "payload": "123456789012",
            "symbology": "EAN13",
            "boundingBox": { "x": 0.7, "y": 0.1, "width": 0.2, "height": 0.1 }
          }
        ]
      }
    ]
  },
  "fullText": "Complete ordered text of entire document..."
}
```

## Implementation Code Snippet (Future)

```swift
// This code will work when macOS 26+ becomes available

func analyzeDocument(imageData: Data) async throws -> DocumentAnalysisResult {
    let request = VNRecognizeDocumentsRequest()

    let handler = VNImageRequestHandler(data: imageData)
    try handler.perform([request])

    guard let observations = request.results as? [VNRecognizeDocumentObservation],
          let documentObservation = observations.first,
          let document = documentObservation.document else {
        throw AnalysisError.noDocumentFound
    }

    var result = DocumentAnalysisResult()

    // Extract tables
    for table in document.tables {
        var tableData = TableData(rowCount: table.rows.count)

        for (rowIndex, row) in table.rows.enumerated() {
            var rowData = RowData()

            for (colIndex, cell) in row.enumerated() {
                let cellText = cell.content.text.transcript
                var detectedData: [DetectedDataItem] = []

                // Extract structured data from cells
                for data in cell.content.text.detectedData {
                    switch data.match.details {
                    case .emailAddress(let email):
                        detectedData.append(.email(email.emailAddress))
                    case .phoneNumber(let phone):
                        detectedData.append(.phone(phone.phoneNumber))
                    case .url(let url):
                        detectedData.append(.url(url.url))
                    case .date(let date):
                        detectedData.append(.date(date))
                    case .money(let money):
                        detectedData.append(.money(amount: money.amount, currency: money.currencyCode))
                    case .flightNumber(let flight):
                        detectedData.append(.flight(airline: flight.airlineCode, number: flight.flightNumber))
                    case .trackingNumber(let tracking):
                        detectedData.append(.tracking(carrier: tracking.carrier, number: tracking.number))
                    default:
                        break
                    }
                }

                let cellData = CellData(
                    text: cellText,
                    rowIndex: rowIndex,
                    columnIndex: colIndex,
                    boundingBox: convertBoundingBox(cell.boundingBox),
                    detectedData: detectedData
                )
                rowData.cells.append(cellData)
            }
            tableData.rows.append(rowData)
        }
        result.tables.append(tableData)
    }

    // Extract paragraphs
    for paragraph in document.paragraphs {
        result.paragraphs.append(ParagraphData(
            text: paragraph.content.text.transcript,
            boundingBox: convertBoundingBox(paragraph.boundingBox),
            confidence: paragraph.confidence
        ))
    }

    // Extract lists
    for list in document.lists {
        var listData = ListData(type: list.type)
        for item in list.items {
            listData.items.append(ListItemData(
                text: item.content.text.transcript,
                level: item.indentationLevel,
                boundingBox: convertBoundingBox(item.boundingBox)
            ))
        }
        result.lists.append(listData)
    }

    return result
}
```

## Benefits Over Current Implementation

### Current `/analyze` Endpoint
- Uses basic `VNRecognizeTextRequest`
- Manual coordinate-based text ordering
- No document structure understanding
- No automatic data detection
- No table parsing

### Future `/analyze-document` Endpoint
- Automatic document structure parsing
- Table extraction with cell-level access
- Built-in data detection (emails, phones, dates, etc.)
- Proper paragraph and list identification
- More accurate reading order
- Integrated barcode detection
- Better multi-column handling

## Migration Path

1. **Current State (macOS 15.5)**
   - Continue using enhanced `VNRecognizeTextRequest` with improved text ordering
   - Provide all current Vision features (body pose, saliency, etc.)

2. **When macOS 26+ Available**
   - Implement `/analyze-document` endpoint
   - Keep `/analyze` endpoint for backward compatibility
   - Document recommends `/analyze-document` for document-heavy use cases
   - `/analyze` remains best for general-purpose image analysis

## Use Cases

Perfect for:
- Invoice processing and data extraction
- Receipt scanning with automatic itemization
- Form parsing (applications, surveys, tax forms)
- Document digitization with structure preservation
- Table extraction from reports and spreadsheets
- Business card parsing
- Package tracking number extraction
- Travel document processing (boarding passes, itineraries)

Not ideal for:
- General photos (use `/analyze` instead)
- Real-time video frame analysis
- Artistic or creative image analysis
- Face/body detection (use `/analyze`)

## References

- [WWDC 2024 - What's new in Vision](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [WWDC 2025 - Vision framework updates](https://developer.apple.com/videos/play/wwdc2025/272/)
- [VNRecognizeDocumentsRequest Documentation](https://developer.apple.com/documentation/vision/vnrecognizedocumentsrequest)

## Timeline

**Estimated Implementation Time:** 3-5 days once macOS 26+ is available
**Priority:** Medium (blocked by OS availability)
**Dependencies:** macOS upgrade, testing with various document types

---

**Last Updated:** October 17, 2025
**Status:** Draft - Awaiting macOS 26+ availability
