# AWS Access Key Creation Guide — `shi-bharatgen` Account

### (Via AWS Console → IAM → Users → *Your Username*)

This document explains how to **create AWS Access Keys** for your IAM user in the `shi-bharatgen` AWS account using the AWS Console.

> ⚠️ Access Keys grant **programmatic access** (CLI / SDKs / Terraform).
> Treat them like passwords.

---

## ✅ Prerequisites

You must have:

* IAM user created
* Permission to create access keys
* MFA enabled (recommended)
* Login access to `shi-bharatgen` AWS account

If not sure — contact the AWS admin team.

---

# 1️⃣ Steps to Create Access Key (Console → IAM → Users)

Follow this exact navigation path:

### **Step 1 — Login**

1. Open: [https://console.aws.amazon.com](https://console.aws.amazon.com)
2. Login to the **`shi-bharatgen`** AWS account

---

### **Step 2 — Go to IAM**

3. In the AWS search bar (top), type **IAM**
4. Click **IAM**

---

### **Step 3 — Open Users Section**

5. From the left sidebar → click **Users**

This opens the list of IAM users.

---

### **Step 4 — Select Your Username**

6. Click your IAM username
   (Example: `john.doe@tihiitb.org`)

You are now on the user summary page.

---

### **Step 5 — Open Security Credentials Tab**

7. Click the tab called:

```
Security credentials
```

---

### **Step 6 — Create New Access Key**

[bottom right of the screen]
8. Scroll to section :

```
Access keys
```

9. Click:

```
Create access key
```

10. Select usage type (usually):

```
Command Line Interface (CLI)
```

11. Confirm and proceed

12. AWS will generate:

* Access Key ID
* Secret Access Key

---

### **Step 7 — Save the Key Securely**

13. Download the `.csv` file
    OR copy + store in password manager

> ⚠️ You CANNOT view the Secret Key again later.

---

# 2️⃣ Verify Your Access Key (Optional but Recommended)

Run:

```bash
aws sts get-caller-identity
```

You should see your account + IAM username.

---


# 4️⃣ If You Lose the Secret Key

AWS **cannot recover it**.

Solution:

1. Create new key
2. Update CLI / apps
3. Disable old key

---

# 5️⃣ Best Practice Security Policies

### ✅ Do This

* Use IAM user (NOT root)
* Keep keys private
* Rotate every **90 days**
* Store ONLY in secure places
* Disable unused keys

---

### ❌ Never Do This

* ❌ Share keys with anyone
* ❌ Commit to GitHub / repos
* ❌ Paste in chat tools
* ❌ Store in plain text files
* ❌ Reuse the same key across services
* ❌ Keep old keys active

---

# 6️⃣ Key Rotation Procedure

1. Create new key
2. Update CLI / tools
3. Test access
4. Disable old key
5. Delete after 24–48h

---

# 7️⃣ If You Suspect Key Leakage 🚨

Do this immediately:

1. Disable key
2. Create replacement
3. Review CloudTrail activity
4. Notify security/admin team
5. Monitor billing + resources

---

# 🛡 Security Summary

| Principle       | Why                     |
| --------------- | ----------------------- |
| Least privilege | Reduce blast radius     |
| Rotate keys     | Prevent long-term abuse |
| Never share     | Prevent leaks           |
| Use IAM roles   | Strongest security      |
| MFA enabled     | Protect login           |

---

# 📌 Notes for `shi-bharatgen` Users

* Use per-user IAM accounts
* Request only required access
* Use CLI profiles for separation
* Avoid root credentials always

---

# 📩 Need Help?

Contact your AWS admin / platform team.


