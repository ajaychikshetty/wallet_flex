const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.processRecurringExpenses = functions.pubsub.schedule("every 24 hours").onRun(async (context) => {
  const now = new Date();
  const currentDate = `${now.getFullYear()}-${("0" + (now.getMonth() + 1)).slice(-2)}-${("0" + now.getDate()).slice(-2)}`;

  // Get all users
  const snapshot = await admin.firestore().collection("user_details").get();
  snapshot.forEach(async (userDoc) => {
    const userId = userDoc.id;
    const recurringRef = admin.firestore().collection("user_details").doc(userId).collection("recurring_pay");

    const recurringSnapshot = await recurringRef.get();
    recurringSnapshot.forEach(async (expenseDoc) => {
      const data = expenseDoc.data();
      const recurrenceType = data.recurrence;
      const startDate = new Date(data.startDate);
      const expenseAmount = data.amount;
      const description = data.description;
      const userBalanceRef = admin.firestore().collection("user_details").doc(userId).collection("balance");

      // Calculate the next occurrence based on the recurrence type
      let nextOccurrence;
      switch (recurrenceType) {
        case "monthly":
          nextOccurrence = new Date(startDate.setMonth(startDate.getMonth() + 1));
          break;
        case "weekly":
          nextOccurrence = new Date(startDate.setDate(startDate.getDate() + 7));
          break;
        case "yearly":
          nextOccurrence = new Date(startDate.setFullYear(startDate.getFullYear() + 1));
          break;
        default:
          nextOccurrence = startDate;
          break;
      }

      // Check if the current date matches the next occurrence
      if (currentDate === `${nextOccurrence.getFullYear()}-${("0" + (nextOccurrence.getMonth() + 1)).slice(-2)}-${("0" + nextOccurrence.getDate()).slice(-2)}`) {
        // Deduct the amount from the user's balance
        const balanceSnapshot = await userBalanceRef.where("date", "==", currentDate).get();
        if (!balanceSnapshot.empty) {
          const balanceDoc = balanceSnapshot.docs[0];
          const existingBalance = balanceDoc.data().amount;
          const newBalance = existingBalance - expenseAmount;

          await userBalanceRef.doc(balanceDoc.id).update({ amount: newBalance });

          // Record the transaction
          await admin.firestore().collection("user_details").doc(userId).collection("transactions").add({
            amount: expenseAmount,
            date: currentDate,
            timestamp: new Date().toISOString(),
            description: description,
            type: "expense",
            isRecurring: true,
            recurrenceType: recurrenceType
          });

          // Update the startDate for the next occurrence
          await expenseDoc.ref.update({ startDate: nextOccurrence.toISOString() });
        }
      }
    });
  });
});
