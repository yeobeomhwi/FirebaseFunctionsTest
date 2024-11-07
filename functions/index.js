const functions = require('firebase-functions/v1');
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendWelcomeEmail = functions.auth.user().onCreate(async (user) => {
    try {
        const userEmail = user.email;
        const userId = user.email;
        console.log(`=== 사용자 추가: ${userEmail} (${userId}) ===`);
        
        // Firestore에서 사용자 관련 token 정보 가져오기
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log(`=== 데이터 없음 ===`);
            return;
        }

        const userData = userDoc.data();
        const userName = userData.name;
        const userToken = userData.token;

        if (!userToken) {
            console.log(`=== 토큰데이터없음 ===`);
            return;
        }

        // FCM 메시지 설정
        const message = {
            token: userToken,
            notification: {
                title: '환영합니다.',
                body: `${userEmail} 님 가입을 축하드립니다.`
            },
        };

        // FCM을 통해 푸시 알림 전송
        const response = await admin.messaging().send(message);
        console.log('Successfully sent notification:', response);
    } catch (error) {
        console.error('Error sending notification:', error);
    }
});

exports.createUser = functions.https.onRequest(async (req, res) => {
    const { email, password, token } = req.body;  // fcmToken 추가

    if (!email || !password) {
        return res.status(400).send('Email, password are required');
    }

    try {
        // Firebase Authentication을 사용하여 사용자 등록
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
        });

        // Firestore에 사용자 정보 저장
        await admin.firestore().collection('users').doc(email).set({
            name: email,
            token: token, // 클라이언트에서 전달받은 FCM 토큰을 Firestore에 저장
        });

        // 성공적인 응답
        res.status(201).json({ uid: userRecord.uid });
    } catch (error) {
        console.error('Error creating user:', error);
        res.status(500).json({ error: error.message });
    }
});
