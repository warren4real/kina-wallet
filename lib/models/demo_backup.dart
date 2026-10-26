// A one-time starting snapshot from our current demo session.
// Once device storage exists, saved data takes priority.
const demoBackupJson = '''
{
  "balanceToea": 133000,
  "transactions": [
    {
      "title": "Electricity demo payment",
      "detail": "Meter: 12345678 · No electricity purchased",
      "amountToea": -2000,
      "icon": "electricity"
    },
    {
      "title": "Demo money added",
      "detail": "Sample funding · No real deposit",
      "amountToea": 100000,
      "icon": "received"
    },
    {
      "title": "Sent to Jeevana",
      "detail": "Demo transfer · +675 73335367",
      "amountToea": -80000,
      "icon": "sent"
    },
    {
      "title": "Sent to Jeevana",
      "detail": "Demo transfer · +675 73335367",
      "amountToea": -5000,
      "icon": "sent"
    },
    {
      "title": "Sent to Jeevana",
      "detail": "Demo transfer · +675 73335367",
      "amountToea": -5000,
      "icon": "sent"
    },
    {
      "title": "Money received",
      "detail": "Family transfer · Today",
      "amountToea": 30000,
      "icon": "received"
    },
    {
      "title": "Electricity",
      "detail": "Sample payment · Yesterday",
      "amountToea": -5000,
      "icon": "electricity"
    },
    {
      "title": "Mobile top-up",
      "detail": "Sample payment · Yesterday",
      "amountToea": -1000,
      "icon": "mobile"
    }
  ]
}
''';
