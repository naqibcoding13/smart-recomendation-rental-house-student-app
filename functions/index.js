const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ⭐ TOYYIBPAY CALLBACK (STAGING)
exports.toyyibpayCallback = functions.https.onRequest(async (req, res) => {
  try {
    const billcode = req.body.billcode;
    const status = req.body.status; // 1 = SUCCESS
    const amount = req.body.amount;

    console.log("Callback Received:", req.body);

    if (!billcode) {
      return res.status(400).send("Missing billcode");
    }

    // FIND BOOKING BY BILL CODE
    const bookingsRef = db.collection("bookings");
    const query = await bookingsRef.where("billCode", "==", billcode).get();

    if (query.empty) {
      console.log("Booking not found for billcode:", billcode);
      return res.status(404).send("Booking not found");
    }

    const booking = query.docs[0];
    const bookingId = booking.id;

    // If paid
    if (status === "1") {
      await bookingsRef.doc(bookingId).update({
        paymentStatus: "paid",
        depositPaidAt: admin.firestore.Timestamp.now(),
        status: "deposit_paid",
      });

      console.log("Payment Updated Successfully");
    }

    return res.status(200).send("Callback Processed");
  } catch (error) {
    console.error("Callback Error:", error);
    return res.status(500).send("Error processing callback");
  }
});
