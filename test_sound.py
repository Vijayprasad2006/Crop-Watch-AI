import winsound
import time

print("Testing Windows Exclamation Beep...")
winsound.MessageBeep(winsound.MB_ICONEXCLAMATION)
time.sleep(1)

print("Testing alternating alarm sequence...")
for _ in range(3):
    winsound.Beep(1000, 400) # frequency, duration (ms)
    winsound.Beep(1500, 400)
    
print("Test complete.")
