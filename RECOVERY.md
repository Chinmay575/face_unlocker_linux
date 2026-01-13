# 🚨 Emergency Recovery Guide

## If Face Unlock Breaks Your Login

Don't panic! Here are **proven recovery methods** to regain access to your system.

---

## 🛟 Method 0: Quick Emergency Script (If Already Logged In)

**If you can still login or access a terminal:**

```bash
cd face_unlock_linux
sudo ./emergency_disable.sh
```

This will:
- Stop the face unlock service
- Disable PAM configuration (with backups)
- Restore password-only authentication

---

## 🔧 Method 1: TTY Console (Easiest)

**Works when graphical login fails but system boots normally:**

1. **Press:** `Ctrl+Alt+F2` (try F3, F4, F5 if F2 doesn't work)
2. **Login with your password** (username + password)
3. **Run these commands:**

```bash
# Stop the service
sudo systemctl stop faceunlock.service
sudo systemctl disable faceunlock.service

# Disable PAM module
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth    # Ubuntu/Debian
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth    # Fedora/Arch

# Return to graphical login
# Press Ctrl+Alt+F1 or Ctrl+Alt+F7
```

4. **Test login** - should now work with password only

---

## 🔐 Method 2: Recovery Mode (If TTY Doesn't Work)

**Works even if regular boot fails:**

1. **Reboot** and hold `Shift` (GRUB) or press `Esc` repeatedly
2. **At GRUB menu:** Select "Advanced options" → "Recovery mode"
3. **Select:** "Drop to root shell prompt"
4. **Run:**

```bash
# Remount filesystem as writable
mount -o remount,rw /

# Disable face unlock in PAM
sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth
sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth

# Delete PAM module (optional but safer)
rm -f /usr/lib/security/pam_faceunlock.so
rm -f /lib/security/pam_faceunlock.so
rm -f /lib/x86_64-linux-gnu/security/pam_faceunlock.so

# Reboot
reboot
```

---

## 💿 Method 3: Live USB (Nuclear Option)

**Works even if system won't boot properly:**

1. **Boot from Live USB** (Ubuntu, Manjaro, any Linux live environment)
2. **Open terminal and mount your system:**

```bash
# Find your root partition
lsblk

# Mount it (replace sdXY with your partition, e.g., sda2, nvme0n1p2)
sudo mount /dev/sdXY /mnt

# Disable face unlock
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /mnt/etc/pam.d/common-auth
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /mnt/etc/pam.d/system-auth

# Remove PAM module completely
sudo rm -f /mnt/usr/lib/security/pam_faceunlock.so
sudo rm -f /mnt/lib/security/pam_faceunlock.so
sudo rm -f /mnt/lib/x86_64-linux-gnu/security/pam_faceunlock.so

# Unmount and reboot
sudo umount /mnt
sudo reboot
```

---

## 🌐 Method 4: SSH Access (Remote Recovery)

**If you have SSH enabled and network access:**

```bash
# From another computer
ssh user@your-computer-ip

# Disable face unlock
sudo systemctl stop faceunlock.service
sudo systemctl disable faceunlock.service
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth
```

---

## 📝 Manual PAM Configuration Edit

**If you prefer to edit files manually:**

The face unlock PAM configuration is in these files:

- **Ubuntu/Debian:** `/etc/pam.d/common-auth`
- **Fedora/Arch:** `/etc/pam.d/system-auth`
- **Also check:** `/etc/pam.d/sudo`, `/etc/pam.d/gdm-password`, `/etc/pam.d/sddm`

**Find and comment out this line:**
```
auth sufficient pam_faceunlock.so
```

**Change to:**
```
# auth sufficient pam_faceunlock.so
```

---

## 🛡️ Prevention Tips

### Before Enabling on Login:

1. **Test with sudo first:**
   ```bash
   sudo -k  # Clear sudo cache
   sudo ls  # Test face unlock
   ```

2. **Keep a backup terminal open** with root access
3. **Test in a TTY console** (Ctrl+Alt+F2) to verify password still works
4. **Enable SSH** as a backup access method
5. **Know how to boot into recovery mode** on your system

### Safe Testing Order:

```
✓ Test 1: sudo commands (safest)
✓ Test 2: Lock screen
✓ Test 3: New terminal session
✗ Test 4: Login screen (only after above work perfectly)
```

---

## 🔍 Quick Diagnosis

### Check if face unlock is active:

```bash
# Check service status
systemctl status faceunlock.service

# Check PAM configuration
grep pam_faceunlock /etc/pam.d/*

# Check if module exists
ls -l /usr/lib/security/pam_faceunlock.so
```

### Verify it's disabled:

```bash
# Service should be inactive
systemctl is-active faceunlock.service    # should return "inactive"

# PAM lines should be commented (start with #)
grep "^[^#]*pam_faceunlock" /etc/pam.d/*  # should return nothing
```

---

## 📞 Still Need Help?

1. **Check logs:**
   ```bash
   sudo journalctl -u faceunlock.service -n 100
   tail -f /var/log/auth.log    # Ubuntu/Debian
   tail -f /var/log/secure      # Fedora/RHEL
   ```

2. **GitHub Issues:** Open an issue with:
   - Your Linux distribution and version
   - Output of `systemctl status faceunlock.service`
   - Output of `grep pam_faceunlock /etc/pam.d/*`
   - Relevant log entries

---

## ✅ After Recovery

Once you've regained access:

1. **Investigate the cause:**
   ```bash
   sudo journalctl -u faceunlock.service -n 100
   ```

2. **Re-enroll if needed:**
   ```bash
   sudo faceunlock-enroll $USER
   ```

3. **Test thoroughly before re-enabling:**
   - Test with `sudo` commands
   - Test lock screen
   - Keep a TTY console open during testing

---

**Remember:** Always have a password backup and know how to access recovery mode!
