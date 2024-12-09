const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.processRecurringExpenses = functions.pubsub.schedule("every 24 hours").onRun(async (context) => {
  const now = new Date();
  const formattedDate = DateFormat('EEE, dd MMM').format(now);

  try {
    const usersSnapshot = await admin.firestore().collection("user_details").get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const batch = admin.firestore().batch();
      
      // Get all active recurring expenses
      const recurringSnapshot = await admin.firestore()
        .collection("user_details")
        .doc(userId)
        .collection("recurring_pay")
        .where('isActive', '==', true)
        .get();

      for (const recurringDoc of recurringSnapshot.docs) {
        const data = recurringDoc.data();
        const lastProcessed = new Date(data.lastProcessed);
        const shouldProcess = shouldProcessRecurringExpense(data.recurrence, lastProcessed, now);

        if (shouldProcess) {
          // Add to expenses collection
          const expenseRef = admin.firestore()
            .collection("user_details")
            .doc(userId)
            .collection("expenses")
            .doc();
            
          batch.set(expenseRef, {
            'amount': data.amount,
            'description': data.description,
            'date': formattedDate,
            'timestamp': now.toISOString(),
            'type': 'expense',
            'isRecurring': true
          });

          // Update lastProcessed timestamp
          batch.update(recurringDoc.ref, {
            'lastProcessed': now.toISOString()
          });

          // Update balance
          const balanceSnapshot = await admin.firestore()
            .collection("user_details")
            .doc(userId)
            .collection("balance")
            .where('date', '==', formatte)
            .get();

          if (!balanceSnapshot.empty) {
            const balanceDoc = balanceSnapshot.docs[0];
            batch.update(balanceDoc.ref, {
              'amount': admin.firestore.FieldValue.increment(-data.amount)
            });
          }

          // Optional: Add to transactions collection if you decide to keep it
          const transactionRef = admin.firestore()
            .collection("user_details")
            .doc(userId)
            .collection("transactions")
            .doc();
            
          batch.set(transactionRef, {
            'amount': data.amount,
            'date': formattedDate,
            'timestamp': now.toISOString(),
            'tname': `${data.description} (Recurring)`,
            'type': 'expense',
            'isRecurring': true
          });
        }
      }

      // Commit all operations atomically
      await batch.commit();
    }
    
    console.log('Successfully processed recurring expenses');
    return null;
  } catch (error) {
    console.error('Error processing recurring expenses:', error);
    throw error;
  }
});

// Helper function to determine if an expense should be processed
function shouldProcessRecurringExpense(recurrence, lastProcessed, now) {
  const daysSinceLastProcess = Math.floor((now - lastProcessed) / (1000 * 60 * 60 * 24));
  
  switch (recurrence) {
    case 'daily':
      return daysSinceLastProcess >= 1;
    case 'weekly':
      return daysSinceLastProcess >= 7;
    case 'monthly':
      // Check if it's been roughly a month (30 days) since last process
      return daysSinceLastProcess >= 30;
    default:
      return false;
  }
}
