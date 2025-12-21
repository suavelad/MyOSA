import os
from firebase_admin import messaging, credentials, initialize_app
from decouple import config


_fcm_app = None
cred_path = config("FCM_CREDENTIALS")
if cred_path:
    cred = credentials.Certificate(cred_path)
    _fcm_app = initialize_app(cred)



def send_push_to_tokens(tokens: list, title: str, body: str, data: dict = None):
    if not _fcm_app or not tokens:
        return None
    message = messaging.MulticastMessage(
    notification=messaging.Notification(title=title, body=body),
    tokens=tokens,
    data={k: str(v) for k,v in (data or {}).items()}
    )
    response = messaging.send_multicast(message)
    return response
