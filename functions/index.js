exports.processRecurringExpenses = functions.pubsub.schedule("every 24 hours").onRun(async (context) => {
  const now = new Date();
  const formattedDate = DateFormat('EEE, dd MMM').format(now);

  try {
    const usersSnapshot = await admin.firestore().collection("user_details").get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const batch = admin.firestore().batch(); // Use batch writes for atomicity
      
      // Get recurring expenses
      const recurringSnapshot = await admin.firestore()
        .collection("user_details")
        .doc(userId)
        .collection("recurring_pay")
        .where('isActive', '==', true)
        .where('recurrence', '==', 'daily')
        .get();

      for (const recurringDoc of recurringSnapshot.docs) {
        const data = recurringDoc.data();
        
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

        // Update balance
        const balanceSnapshot = await admin.firestore()
          .collection("user_details")
          .doc(userId)
          .collection("balance")
          .where('date', '==', formattedDate)
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
