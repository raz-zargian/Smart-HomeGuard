importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyB_k6-tNwDXM4qd1B6iKkoyRLWWuRPeHgE",
    projectId: "smarthomeguard-7dafd",
    messagingSenderId: "696184557049",
    appId: "1:696184557049:web:0fa320a9865d8733fc0128"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('this check worked', payload);

    const notificationTitle = payload.notification.title || 'new notification';
    const notificationOptions = {
        body: payload.notification.body || 'click here to open',
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});


// flutter run -d web-server --web-port=8080