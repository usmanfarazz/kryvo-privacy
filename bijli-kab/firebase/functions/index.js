// Optional (needs the Firebase Blaze plan): when an area's state flips,
// push a notification to everyone following it (topic `area_<geohash>`).
// Without this the app still warns before predicted cuts and shows live
// changes while it is open.
const { onDocumentUpdated, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

async function notify(areaId, data) {
  const off = data.state === 'off';
  const place = data.place || 'your area';
  await getMessaging().send({
    topic: `area_${areaId}`,
    notification: {
      title: off ? `💡❌ Light gayi — ${place}` : `💡✅ Light aa gayi — ${place}`,
      body: off
        ? 'Neighbours just reported a power cut.'
        : 'Neighbours just reported the power is back.',
    },
    android: {
      priority: 'high',
      collapseKey: `area_${areaId}`,
      notification: { channelId: 'bk_live', icon: 'ic_stat_bolt', color: '#FFD60A' },
    },
    data: { area: areaId, state: data.state },
  });
}

exports.onAreaCreated = onDocumentCreated('areas/{areaId}', async (event) => {
  const data = event.data?.data();
  if (data) await notify(event.params.areaId, data);
});

exports.onAreaUpdated = onDocumentUpdated('areas/{areaId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.state === after.state) return;
  await notify(event.params.areaId, after);
});
