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
const HEADERS = ['id', 'title', 'body', 'scheduledTime', 'repeatFrequency', 'isActive', 'priority', 'customInterval', 'customUnit'];

function getSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];
  if (!sheet) throw new Error('No sheets found in this spreadsheet.');

  // Check and update headers if necessary
  const lastCol = sheet.getLastColumn();
  const currentHeaders = lastCol > 0 ? sheet.getRange(1, 1, 1, lastCol).getValues()[0] : [];

  if (currentHeaders.length < HEADERS.length) {
    sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
  }

  return sheet;
}

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
        const priority = get('priority', 6) || 'medium';
        const customInterval = get('custominterval', 7);
        const customUnit = get('customunit', 8);

        if (!id || !rawTime) return null;

        let scheduledTime;
        if (rawTime instanceof Date) {
          scheduledTime = rawTime.toISOString();
        } else {
          scheduledTime = String(rawTime);
        }

        return {
          id: Number(id),
          title: title,
          body: body,
          scheduledTime: scheduledTime,
          repeatFrequency: freq ? String(freq) : 'none',
          isActive: String(activeRaw).toLowerCase() === 'true' || activeRaw === true,
          priority: String(priority),
          customInterval: customInterval !== '' ? Number(customInterval) : null,
          customUnit: customUnit !== '' ? String(customUnit) : null
        };
      } catch (err) {
        return null;
      }
    })
    .filter(r => r !== null);
}

function upsertReminder(reminder) {
  const sheet = getSheet();
  const data = sheet.getDataRange().getValues();

  let rowIndex = -1;
  for (let i = 1; i < data.length; i++) {
    if (Number(data[i][0]) === Number(reminder.id)) {
      rowIndex = i + 1;
      break;
    }
  }
  if (rowIndex === -1) rowIndex = data.length + 1;

  sheet.getRange(rowIndex, 1, 1, HEADERS.length).setValues([[
    reminder.id,
    reminder.title,
    reminder.body,
    reminder.scheduledTime,
    reminder.repeatFrequency || 'none',
    reminder.isActive.toString(),
    reminder.priority || 'medium',
    reminder.customInterval || '',
    reminder.customUnit || ''
  ]]);
  return { success: true };
}

function cancelReminder(id) {
  const sheet = getSheet();
  const colMap = getColumnMap(sheet);
  const data = sheet.getDataRange().getValues();
  const activeCol = (colMap['isactive'] !== undefined ? colMap['isactive'] : 5) + 1;

  for (let i = 1; i < data.length; i++) {
    if (Number(data[i][0]) === id) {
      sheet.getRange(i + 1, activeCol).setValue('false');
      return { success: true };
    }
  }
  return { error: 'Reminder not found with id: ' + id };
}
