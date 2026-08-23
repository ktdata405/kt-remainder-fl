// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE APPS SCRIPT — Reminder Web API
//
// HOW TO DEPLOY (one-time, free):
//  1. Open your Google Sheet
//  2. Click Extensions → Apps Script
//  3. Delete any existing code and paste this entire file
//  4. Click Deploy → New deployment → Web app
//     • Execute as: Me
//     • Who has access: Anyone
//  5. Click Deploy → copy the Web app URL
//  6. Paste that URL into lib/config/app_config.dart as kWebAppUrl
// ─────────────────────────────────────────────────────────────────────────────

const SHEET_NAME = 'Reminders';
const HEADERS = ['id', 'title', 'body', 'scheduledTime', 'repeatFrequency', 'isActive'];

function getSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Try the dedicated "Reminders" tab first, then fall back to the first sheet.
  let sheet = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];

  if (!sheet) throw new Error('No sheets found in this spreadsheet.');

  // Check whether row 1 already has our expected headers.
  const lastCol = Math.max(sheet.getLastColumn(), HEADERS.length);
  const firstRow = sheet.getRange(1, 1, 1, lastCol).getValues()[0];
  const hasHeaders = firstRow[0] !== '' && firstRow[0] !== null;

  if (!hasHeaders) {
    // Empty sheet — write headers.
    sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
  }

  return sheet;
}

// Return the column index (0-based) for each expected header, handling sheets
// where columns might be in a different order.
function getColumnMap(sheet) {
  const row = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const map = {};
  row.forEach((cell, i) => {
    if (cell !== '') map[cell.toString().trim().toLowerCase()] = i;
  });
  return map;
}

function doGet(e) {
  let result;
  try {
    const action = (e.parameter && e.parameter.action) ? e.parameter.action : 'fetch';
    if (action === 'fetch') {
      result = fetchReminders();
    } else if (action === 'upsert') {
      const data = JSON.parse(decodeURIComponent(e.parameter.data));
      result = upsertReminder(data);
    } else if (action === 'cancel') {
      result = cancelReminder(Number(e.parameter.id));
    } else {
      result = { error: 'Unknown action: ' + action };
    }
  } catch (err) {
    result = { error: err.toString() };
  }
  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function fetchReminders() {
  const sheet = getSheet();
  const colMap = getColumnMap(sheet);
  const data = sheet.getDataRange().getValues();

  if (data.length <= 1) return [];

  return data.slice(1)
    .filter(row => row.some(cell => cell !== '' && cell !== null))
    .map(row => {
      try {
        // Use column map for flexibility; fall back to positional if header not found.
        const get = (key, pos) => {
          const i = colMap[key] !== undefined ? colMap[key] : pos;
          return i < row.length ? row[i] : '';
        };

        const id = get('id', 0);
        const title = String(get('title', 1));
        const body = String(get('body', 2));
        const rawTime = get('scheduledtime', 3);
        const freq = get('repeatfrequency', 4);
        const activeRaw = get('isactive', 5);

        if (!id || !rawTime) return null;

        // Normalise date in script timezone (wall clock), not UTC.
        let scheduledTime;
        if (rawTime instanceof Date) {
          scheduledTime = Utilities.formatDate(
            rawTime,
            Session.getScriptTimeZone(),
            "yyyy-MM-dd'T'HH:mm:ss"
          );
        } else {
          scheduledTime = String(rawTime);
        }

        return {
          id: Number(id),
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          repeatFrequency: freq ? String(freq) : 'none',
          isActive: String(activeRaw).toLowerCase() === 'true' || activeRaw === true
        };
      } catch (err) {
        return null;
      }
    })
    .filter(r => r !== null);
}

function upsertReminder(reminder) {
  const sheet = getSheet();
  const colMap = getColumnMap(sheet);
  const data = sheet.getDataRange().getValues();

  // If the sheet doesn't have our headers yet, add them.
  const hasOurHeaders = colMap['id'] !== undefined && colMap['scheduledtime'] !== undefined;
  if (!hasOurHeaders) {
    // Append columns or start fresh if sheet is truly empty of structure.
    if (data.length === 0 || (data.length === 1 && data[0].every(c => c === ''))) {
      sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
    }
  }

  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (Number(data[i][0]) === Number(reminder.id)) {
      rowIndex = i + 1;
      break;
    }
  }
  if (rowIndex === -1) rowIndex = data.length + 1;

  sheet.getRange(rowIndex, 1, 1, 6).setValues([[
    reminder.id,
    reminder.title,
    reminder.body,
    reminder.scheduledTime,
    reminder.repeatFrequency || 'none',
    reminder.isActive.toString()
  ]]);
  return { success: true };
}

function cancelReminder(id) {
  const sheet = getSheet();
  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (Number(data[i][0]) === id) {
      sheet.getRange(i + 1, 6).setValue('false');
      return { success: true };
    }
  }
  return { error: 'Reminder not found with id: ' + id };
}
