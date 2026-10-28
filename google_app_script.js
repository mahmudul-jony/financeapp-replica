/**
 * Google Apps Script for FinanceApp Google Sheets Sync
 * 
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Open Google Sheets → Extensions → Apps Script
 * 2. Replace all code with this file's content
 * 3. Save → Deploy → Manage Deployments → Edit (✏️) → New Version → Deploy
 * 4. Execute as: Me | Who has access: Anyone
 * 5. URL remains the same!
 * 
 * COLUMNS (A-G):
 * A: ID | B: Date | C: Title/Category | D: Transaction Type | E: Amount | F: Note | G: Wallet Name
 * 
 * ID FORMAT: txid_000001, txid_000002, ...
 */

function doGet(e) {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheets = ss.getSheets();
    var idMap = {};
    var warnings = [];
    var sameTabSeen = {};
    var tz = ss.getSpreadsheetTimeZone();

    // Pass 1: Find the maximum txid number across all sheets
    var maxTxNum = 0;
    for (var s = 0; s < sheets.length; s++) {
      var sData = sheets[s].getDataRange().getValues();
      for (var r = 1; r < sData.length; r++) {
        var existingId = sData[r][0] ? sData[r][0].toString().trim() : "";
        var match = existingId.match(/^txid_(\d+)$/i);
        if (match) {
          var num = parseInt(match[1], 10);
          if (num > maxTxNum) maxTxNum = num;
        }
      }
    }

    // Pass 2: Process all rows and assign sequential txid_000000 to empty rows
    for (var i = 0; i < sheets.length; i++) {
      var sheet = sheets[i];
      var sheetName = sheet.getName();
      var data = sheet.getDataRange().getValues();
      var displayData = sheet.getDataRange().getDisplayValues();

      if (data.length > 1) {
        for (var j = 1; j < data.length; j++) {
          var row = data[j];

          // Check if this row has any financial data (Date, Title, Type, Amount, Note, Wallet)
          var hasData = false;
          for (var col = 1; col < 7; col++) {
            if (row[col] !== "" && row[col] !== null && row[col] !== undefined) {
              hasData = true;
              break;
            }
          }
          if (!hasData) continue;

          var id = row[0] ? row[0].toString().trim() : "";

          // If ID is missing (user added row directly in Google Sheets):
          // Generate sequential ID in txid_000001 format and save it into Column A
          if (!id) {
            maxTxNum++;
            id = "txid_" + padZero(maxTxNum, 6);
            sheet.getRange(j + 1, 1).setValue(id);
            row[0] = id;
          }

          // Duplicate validation: check for duplicate ID within the same tab
          var sameTabKey = sheetName + "::" + id;
          if (sameTabSeen[sameTabKey]) {
            warnings.push("Duplicate ID '" + id + "' found multiple times within tab '" + sheetName + "' at row " + (j + 1));
          } else {
            sameTabSeen[sameTabKey] = true;
          }

          var rawDate = row[1];
          var dateStr = "";
          if (rawDate instanceof Date) {
            dateStr = Utilities.formatDate(rawDate, tz, "dd-MM-yy");
          } else {
            dateStr = displayData[j][1] ? displayData[j][1].toString() : (rawDate ? rawDate.toString() : "");
          }

          var titleCategory = row[2] ? row[2].toString().trim() : "";
          var transectionType = row[3] ? row[3].toString().trim() : "";
          var amount = row[4] !== "" ? row[4] : 0;
          var note = row[5] ? row[5].toString() : "";
          var walletName = row[6] ? row[6].toString().trim() : sheetName;

          var record = {
            "id": id,
            "date": dateStr,
            "titleCategory": titleCategory,
            "transectionType": transectionType,
            "amount": amount,
            "note": note,
            "walletName": walletName,
            "sheetName": sheetName
          };

          // Deduplication across multiple projection sheets:
          if (idMap[id]) {
            var existing = idMap[id];

            // Validate cross-tab data compatibility
            var amountDiff = Math.abs(parseFloat(amount || 0) - parseFloat(existing.amount || 0));
            if (amountDiff > 0.01) {
              warnings.push("Incompatible amount for ID '" + id + "' between tab '" + existing.sheetName + "' (" + existing.amount + ") and tab '" + sheetName + "' (" + amount + ")");
            }

            // Prefer the "To " entry for transfers because it preserves source wallet
            if (titleCategory.indexOf("To ") === 0) {
              idMap[id] = record;
            } else if (existing.titleCategory.indexOf("To ") === 0) {
              // Keep existing "To " entry
            } else if (sheetName !== "Loans" && existing.sheetName === "Loans") {
              // Prefer wallet tab over projection tab "Loans"
              idMap[id] = record;
            }
          } else {
            idMap[id] = record;
          }
        }
      }
    }

    var allData = [];
    for (var key in idMap) {
      if (idMap.hasOwnProperty(key)) {
        allData.push(idMap[key]);
      }
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      data: allData,
      warnings: warnings
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    console.error("doGet error: " + error);
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: error.toString(),
      data: [],
      warnings: []
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    var contents;
    if (e.postData && e.postData.contents) {
      contents = JSON.parse(e.postData.contents);
    } else if (e.parameter) {
      contents = e.parameter;
    } else {
      throw new Error("No data received");
    }

    var action = contents.action;
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    // 1. Batch Sync: Process multiple operations in a single atomic request
    if (action === "batch_sync") {
      var operations = contents.operations || [];
      var processedIds = [];
      var failedOps = [];

      for (var b = 0; b < operations.length; b++) {
        var op = operations[b];
        var opAction = op.action;
        var opPayload = op.payload || {};

        try {
          if (opAction === "delete") {
            deleteTransactionRows(ss, opPayload.id);
            if (opPayload.id) processedIds.push(opPayload.id);
          } else if (opAction === "create" || opAction === "upsert" || opAction === "update") {
            upsertTransaction(ss, opPayload);
            if (opPayload.id) processedIds.push(opPayload.id);
          } else if (opAction === "create_tab") {
            if (opPayload.tabName && !ss.getSheetByName(opPayload.tabName)) {
              createSheetWithHeaders(ss, opPayload.tabName);
            }
            if (opPayload.tabName) processedIds.push("tab_" + opPayload.tabName);
          } else if (opAction === "rename_tab") {
            renameTabInternal(ss, opPayload.oldTabName, opPayload.newTabName);
            if (opPayload.oldTabName) processedIds.push("rename_" + opPayload.oldTabName);
          } else if (opAction === "update_wallet_name") {
            updateWalletNameInternal(ss, opPayload.oldName, opPayload.newName);
            if (opPayload.oldName) processedIds.push("wallet_" + opPayload.oldName);
          } else if (opAction === "update_category_name") {
            updateCategoryNameInternal(ss, opPayload.oldName, opPayload.newName);
            if (opPayload.oldName) processedIds.push("cat_" + opPayload.oldName);
          }
        } catch (opErr) {
          console.error("Batch op failed at index " + b + ": " + opErr);
          failedOps.push({ action: opAction, id: opPayload.id, error: opErr.toString() });
        }
      }

      return jsonResponse({
        status: failedOps.length === 0 ? "success" : (processedIds.length > 0 ? "partial" : "error"),
        action: "batch_sync",
        processedCount: processedIds.length,
        processedIds: processedIds,
        failedOps: failedOps
      });
    }

    // 2. Create Tab
    if (action === "create_tab") {
      var tabName = contents.tabName;
      if (tabName && !ss.getSheetByName(tabName)) {
        createSheetWithHeaders(ss, tabName);
      }
      return jsonResponse({ status: "success", action: "create_tab", tabName: tabName });
    }

    // 3. Rename Tab
    if (action === "rename_tab") {
      renameTabInternal(ss, contents.oldTabName, contents.newTabName);
      return jsonResponse({ status: "success", action: "rename_tab" });
    }

    // 4. Update Category / Title Name across ALL sheets
    if (action === "update_category_name") {
      updateCategoryNameInternal(ss, contents.oldName, contents.newName);
      return jsonResponse({ status: "success", action: "update_category_name" });
    }

    // 5. Update Wallet Name across ALL sheets (Column G)
    if (action === "update_wallet_name") {
      updateWalletNameInternal(ss, contents.oldName, contents.newName);
      return jsonResponse({ status: "success", action: "update_wallet_name" });
    }

    // 6. Create / Upsert Transaction (Idempotent: updates existing row, appends if new)
    if (action === "create" || action === "create_wallet" || action === "upsert" || action === "update") {
      var payload = contents.payload;
      if (!payload) throw new Error("Missing payload");

      upsertTransaction(ss, payload);
      return jsonResponse({ status: "success", action: action, id: payload.id });
    }

    // 7. Delete Transaction across all sheets
    if (action === "delete") {
      var idToDelete = (contents.payload && contents.payload.id) ? contents.payload.id : contents.id;
      if (!idToDelete) throw new Error("Missing transaction id to delete");

      deleteTransactionRows(ss, idToDelete);
      return jsonResponse({ status: "success", action: "delete", id: idToDelete });
    }

    // 8. Reset Sheet
    if (action === "reset") {
      var sheets = ss.getSheets();
      for (var rIdx = 0; rIdx < sheets.length; rIdx++) {
        if (rIdx === 0) {
          sheets[rIdx].setName("Main Wallet");
          sheets[rIdx].clear();
          addHeaders(sheets[rIdx]);
        } else {
          ss.deleteSheet(sheets[rIdx]);
        }
      }
      createSheetWithHeaders(ss, "Loans");
      return jsonResponse({ status: "success", action: "reset" });
    }

    return jsonResponse({ status: "error", message: "Unknown action: " + action });
  } catch (error) {
    console.error("doPost error: " + error + "\nStack: " + error.stack);
    return jsonResponse({ status: "error", message: error.toString() });
  }
}

function upsertTransaction(ss, payload) {
  var walletName = payload.walletName || "Main Wallet";
  var secondaryTabName = payload.secondaryTabName || null;

  // 1. Write / Update Primary Wallet Tab
  if (walletName && walletName !== "N/A" && walletName !== "None") {
    upsertTransactionRow(ss, walletName, payload);
  }

  // 2. Write / Update Secondary Tab (transfers, investments, savings)
  if (secondaryTabName && secondaryTabName !== walletName && secondaryTabName !== "N/A" && secondaryTabName !== "None") {
    upsertTransactionRow(ss, secondaryTabName, payload);
  }

  // 3. Write / Update "Loans" tab for loan transactions
  var typeLabel = payload.transectionType || "";
  if (typeLabel.indexOf("Loan") !== -1 || typeLabel.indexOf("loan") !== -1) {
    if (secondaryTabName !== "Loans") {
      upsertTransactionRow(ss, "Loans", payload);
    }
  }
}

function upsertTransactionRow(ss, sheetName, payload) {
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = createSheetWithHeaders(ss, sheetName);
  }

  var id = payload.id !== undefined && payload.id !== null ? payload.id.toString() : "";
  var date = payload.date || "";
  var titleCategory = payload.titleCategory || "";
  var transectionType = payload.transectionType || "";
  var amount = payload.amount !== undefined ? payload.amount : 0;
  var note = payload.note || "";
  var walletName = payload.walletName || sheetName;

  var data = sheet.getDataRange().getValues();
  var foundRow = -1;

  if (id) {
    for (var r = 1; r < data.length; r++) {
      if (data[r][0] && data[r][0].toString().trim() === id) {
        foundRow = r + 1; // 1-based index
        break;
      }
    }
  }

  var rowValues = [id, date, titleCategory, transectionType, amount, note, walletName];

  if (foundRow > 0) {
    // Update existing row in place (Prevents duplicates on retry!)
    sheet.getRange(foundRow, 1, 1, 7).setValues([rowValues]);
  } else {
    // Append new row
    sheet.appendRow(rowValues);
  }
}

function deleteTransactionRows(ss, id) {
  if (!id) return;
  var targetId = id.toString().trim();
  var sheets = ss.getSheets();

  for (var i = 0; i < sheets.length; i++) {
    var sheet = sheets[i];
    var data = sheet.getDataRange().getValues();
    // Loop backwards to safely delete multiple rows if present
    for (var r = data.length - 1; r >= 1; r--) {
      if (data[r][0] && data[r][0].toString().trim() === targetId) {
        sheet.deleteRow(r + 1);
      }
    }
  }
}

function renameTabInternal(ss, oldTabName, newTabName) {
  var oldNorm = oldTabName ? oldTabName.toString().trim().toLowerCase() : "";
  var newClean = newTabName ? newTabName.toString().trim() : "";
  if (oldNorm && newClean) {
    var sheets = ss.getSheets();
    for (var sIdx = 0; sIdx < sheets.length; sIdx++) {
      if (sheets[sIdx].getName().trim().toLowerCase() === oldNorm) {
        sheets[sIdx].setName(newClean);
        break;
      }
    }
  }
}

function updateCategoryNameInternal(ss, oldName, newName) {
  var oldNorm = oldName ? oldName.toString().trim().toLowerCase() : "";
  var newClean = newName ? newName.toString().trim() : "";
  if (oldNorm && newClean) {
    var sheets = ss.getSheets();
    for (var k = 0; k < sheets.length; k++) {
      var sheet = sheets[k];
      var data = sheet.getDataRange().getValues();
      for (var r = 1; r < data.length; r++) {
        if (data[r][2] && data[r][2].toString().trim().toLowerCase() === oldNorm) {
          sheet.getRange(r + 1, 3).setValue(newClean);
        }
      }
    }
  }
}

function updateWalletNameInternal(ss, oldName, newName) {
  var oldNorm = oldName ? oldName.toString().trim().toLowerCase() : "";
  var newClean = newName ? newName.toString().trim() : "";
  if (oldNorm && newClean) {
    var sheets = ss.getSheets();
    for (var w = 0; w < sheets.length; w++) {
      var s = sheets[w];
      var d = s.getDataRange().getValues();
      for (var rowIdx = 1; rowIdx < d.length; rowIdx++) {
        if (d[rowIdx][6] && d[rowIdx][6].toString().trim().toLowerCase() === oldNorm) {
          s.getRange(rowIdx + 1, 7).setValue(newClean);
        }
      }
    }
  }
}

function createSheetWithHeaders(ss, name) {
  var sheet = ss.insertSheet(name);
  addHeaders(sheet);
  return sheet;
}

function addHeaders(sheet) {
  sheet.appendRow(["ID", "Date", "Title / Category", "Transaction Type", "Amount", "Note", "Wallet Name"]);
  sheet.getRange("A1:G1").setFontWeight("bold").setBackground("#f3f3f3");
  sheet.setFrozenRows(1);
}

function padZero(num, size) {
  var s = num + "";
  while (s.length < size) s = "0" + s;
  return s;
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
