Flutter integration
When
Call
App open / inbox badge
GET /api/chat/unread-count
Open chat screen
GET /api/chat/history/{id} (auto read) or PUT /api/chat/read/{id}
Mark all read button
PUT /api/chat/read
Inbox list badges
Use unread_count / has_unread from GET /api/chat/user

Note: is_read on a message means the receiver has read it. Only the receiver can mark read/unread.



New APIs
Header (all requests): token: {{yourToken}}
1. Unread count
GET {{baseUrl}}/api/chat/unread-count
Response:
{
 "status": "success",
 "message": "Unread count retrieved",
 "data": {
   "total_unread": 3,
   "conversations": [
     { "partner_id": 20, "unread_count": 2 },
     { "partner_id": 45, "unread_count": 1 }
   ]
 }
}

2. Mark one conversation as read
PUT {{baseUrl}}/api/chat/read/{partner_id}
Example: PUT /api/chat/read/20
Response:
{
 "status": "success",
 "message": "Conversation marked as read",
 "data": {
   "partner_id": 20,
   "marked_read": 2
 }
}

3. Mark all chats as read
PUT {{baseUrl}}/api/chat/read
Response:
{
 "status": "success",
 "message": "All chats marked as read",
 "data": { "marked_read": 5 }
}

4. Mark one message as read
PUT {{baseUrl}}/api/chat/message/{message_id}/read

5. Mark one message as unread
PUT {{baseUrl}}/api/chat/message/{message_id}/unread

6. Mark whole conversation as unread
PUT {{baseUrl}}/api/chat/unread/{partner_id}

