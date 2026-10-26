/**
 * Google Apps Script for FinanceApp Google Sheets Sync
 * 
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Open Google Sheets → Extensions → Apps Script
 * 2. Replace all code with this file's content
 * 3. Save → Deploy → New Deployment → Web App
 * 4. Execute as: Me | Who has access: Anyone
 * 5. Copy the new URL and update _scriptUrl in lib/services/sync_service.dart
 * 
 * COLUMNS (A-G):
 * A: ID | B: Date | C: Title/Category | D: Transaction Type | E: Amount | F: Note | G: Wallet Name
 */

function doGet(e) {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheets = ss.getSheets();
    var allData = [];
    var tz = ss.getSpreadsheetTimeZone();

    for (var i = 0; i < sheets.length; i++) {
      var sheet = sheets[i];
      var data = sheet.getDataRange().getValues();
      var displayData = sheet.getDataRange().getDisplayValues();

      if (data.length > 1) {
        for (var j = 1; j < data.length; j++) {
          var row = data[j];
          if (row[0]) {  // ID exists
            var rawDate = row[1];
            var dateStr = "";

            if (rawDate instanceof Date) {
              // Return in Flutter-expected format: DD-MM-YY
              dateStr = Utilities.formatDate(rawDate, tz, "dd-MM-yy");
            } else {
              dateStr = displayData[j][1] ? displayData[j][1].toString() : rawDate.toString();
            }

            allData.push({
              "id": row[0],
              "date": dateStr,
              "titleCategory": row[2],
              "transectionType": row[3],
              "amount": row[4],
              "note": row[5],
              "walletName": row[6]
            });
          }
        }
      }
    }
    return ContentService.createTextOutput(JSON.stringify(allData)).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    console.error("doGet error: " + error);
    return ContentService.createTextOutput(JSON.stringify([])).setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    // Handle both JSON and form data
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

    // 1. Create a new Tab
    if (action === "create_tab") {
      var tabName = contents.tabName;
      if (tabName && !ss.getSheetByName(tabName)) {
        createSheetWithHeaders(ss, tabName);
      }
      return jsonResponse({ status: "success", action: "create_tab", tabName: tabName });
    }

    // 2. Rename a Tab
    if (action === "rename_tab") {
      var oldTabName = contents.oldTabName ? contents.oldTabName.toString().trim().toLowerCase() : "";
      var newTabName = contents.newTabName ? contents.newTabName.toString().trim() : "";
      if (oldTabName && newTabName) {
        var sheets = ss.getSheets();
        for (var sIdx = 0; sIdx < sheets.length; sIdx++) {
          if (sheets[sIdx].getName().trim().toLowerCase() === oldTabName) {
            sheets[sIdx].setName(newTabName);
            break;
          }
        }
      }
      return jsonResponse({ status: "success", action: "rename_tab" });
    }

    // 3. Update Category / Title Name across ALL sheets
    if (action === "update_category_name") {
      var oldName = contents.oldName ? contents.oldName.toString().trim().toLowerCase() : "";
      var newName = contents.newName ? contents.newName.toString().trim() : "";
      if (oldName && newName) {
        var sheets = ss.getSheets();
        for (var k = 0; k < sheets.length; k++) {
          var sheet = sheets[k];
          var data = sheet.getDataRange().getValues();
          for (var r = 1; r < data.length; r++) {
            if (data[r][2] && data[r][2].toString().trim().toLowerCase() === oldName) {
              sheet.getRange(r + 1, 3).setValue(newName);
            }
          }
        }
      }
      return jsonResponse({ status: "success", action: "update_category_name" });
    }

    // 4. Update Wallet Name across ALL sheets (Column G / 7th Column)
    if (action === "update_wallet_name") {
      var oldWallet = contents.oldName ? contents.oldName.toString().trim().toLowerCase() : "";
      var newWallet = contents.newName ? contents.newName.toString().trim() : "";
      if (oldWallet && newWallet) {
        var sheets = ss.getSheets();
        for (var w = 0; w < sheets.length; w++) {
          var s = sheets[w];
          var d = s.getDataRange().getValues();
          for (var rowIdx = 1; rowIdx < d.length; rowIdx++) {
            if (d[rowIdx][6] && d[rowIdx][6].toString().trim().toLowerCase() === oldWallet) {
              s.getRange(rowIdx + 1, 7).setValue(newWallet);
            }
          }
        }
      }
      return jsonResponse({ status: "success", action: "update_wallet_name" });
    }

    // 5. Create Transaction / Dual Entry (for transfers)
    if (action === "create" || action === "create_wallet") {
      var payload = contents.payload;
      if (!payload) {
        throw new Error("Missing payload");
      }

      var walletName = payload.walletName || "Main Wallet";
      var secondaryTabName = payload.secondaryTabName || null;

      // Write to Primary Wallet TAB (only if valid wallet and not N/A)
      if (walletName && walletName !== "N/A" && walletName !== "None") {
        appendTransactionRow(ss, walletName, payload);
      }

      // Write to Secondary TAB (for transfers, loans, investments, savings)
      if (secondaryTabName && secondaryTabName !== walletName && secondaryTabName !== "N/A" && secondaryTabName !== "None") {
        appendTransactionRow(ss, secondaryTabName, payload);
      }

      // Also write to "Loans" tab for loan transactions
      var typeLabel = payload.transectionType || "";
      if (typeLabel.indexOf("Loan") !== -1 || typeLabel.indexOf("loan") !== -1) {
        if (payload.secondaryTabName !== "Loans") {
          appendTransactionRow(ss, "Loans", payload);
        }
      }

      return jsonResponse({ status: "success", action: "create", id: payload.id });
    }

    // 6. Reset Sheet
    if (action === "reset") {
      var sheets = ss.getSheets();
      for (var i = 0; i < sheets.length; i++) {
        if (i === 0) {
          sheets[i].setName("Main Wallet");
          sheets[i].clear();
          addHeaders(sheets[i]);
        } else {
          ss.deleteSheet(sheets[i]);
        }
      }
      createSheetWithHeaders(ss, "Loans");
      return jsonResponse({ status: "success", action: "reset" });
    }

    // Unknown action
    return jsonResponse({ status: "error", message: "Unknown action: " + action });

  } catch (error) {
    console.error("doPost error: " + error + "\nStack: " + error.stack);
    return jsonResponse({ status: "error", message: error.toString() });
  }
}

function appendTransactionRow(ss, sheetName, payload) {
  try {
    var sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      sheet = createSheetWithHeaders(ss, sheetName);
    }

    // Ensure ID is present
    var id = payload.id || "";
    var date = payload.date || "";
    var titleCategory = payload.titleCategory || "";
    var transectionType = payload.transectionType || "";
    var amount = payload.amount || 0;
    var note = payload.note || "";
    var walletName = payload.walletName || sheetName;

    sheet.appendRow([
      id,
      date,
      titleCategory,
      transectionType,
      amount,
      note,
      walletName
    ]);

    // Log for debugging
    console.log("Appended to " + sheetName + ": ID=" + id + ", Type=" + transectionType + ", Amount=" + amount);
  } catch (error) {
    console.error("appendTransactionRow error for sheet " + sheetName + ": " + error);
    throw error;
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
  // Freeze header row
  sheet.setFrozenRows(1);
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}