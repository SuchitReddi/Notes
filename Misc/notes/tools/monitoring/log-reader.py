import smtplib, ssl
#import string
import os
#from time import strftime
#import sys

TO_ADDRESS = 'REDACTED'
SMTP_SERVER = 'smtp.gmail.com'

SMTP_USERNAME = "REDACTED"
SMTP_PASSWORD = "REDACTED"

context = ssl.create_default_context()

EMAILTEMPLATE = """From: RPi - piserver
Subject: New Events on RPi

The game is on! Is this real?

"""

LOGFILE = '/var/log/opencanary.log'
POSITION_FILE = '/var/log/.opencanary_last_pos'

context = ssl.create_default_context()

def findParam(sourceEvent, checkString):
    result = ""
    fullCheckString = '"' + checkString + '": '
    startChar = sourceEvent.find(fullCheckString)
    if startChar > 0:
        startChar += len(fullCheckString)
        endChar = sourceEvent.find(',', startChar)
        if endChar < 0:
            endChar = sourceEvent.find('}', startChar)
        if endChar > 0:
            result = sourceEvent[startChar:endChar].strip('" ')
    return result

# basic parser for each line of text to see if it is one of the whitelisted events that do not need reporting
def CheckLine(sourceEvent):
    sendTheEmail = True

    sourceIP   = findParam(sourceEvent, "src_host")
    destIP     = findParam(sourceEvent, "dst_host")
    destPort   = findParam(sourceEvent, "dst_port")
    sourcePort = findParam(sourceEvent, "src_port")
    logType    = findParam(sourceEvent, "logtype")

    # better code would be to use a config file, but for now let's just add some simple cases
    if logType == "1001":
        sendTheEmail = False


    # Map log types to human-readable names
    event_name = "UNKNOWN"
    if sendTheEmail:
        if logType == "1001": event_name = "Service Started"
        elif logType == "1002": event_name = "Debug Message"
        elif logType == "1003": event_name = "Error Log"
        elif logType == "2000": event_name = "FTP Login Attempt"
        elif logType == "2001": event_name = "FTP Auth Init"
        elif logType == "3000": event_name = "HTTP GET Request"
        elif logType == "3001": event_name = "HTTP POST Login"
        elif logType == "4000": event_name = "SSH New Connection"
        elif logType == "4001": event_name = "SSH Version Sent"
        elif logType == "4002": event_name = "SSH Login Attempt"
        elif logType == "5000": event_name = "SMB File Open"
        elif logType == "5001": event_name = "Port Scan (SYN)"
        elif logType == "5002": event_name = "Port Scan (NMAP)"
        elif logType == "6001": event_name = "Telnet Login Attempt"
        elif logType == "6002": event_name = "Telnet Connection"
        elif logType == "7001": event_name = "HTTP Proxy Login"
        elif logType == "8001": event_name = "MySQL Login Attempt"
        elif logType == "9001": event_name = "MSSQL Auth (SQL)"
        elif logType == "9002": event_name = "MSSQL Auth (Win)"
        elif logType == "10001": event_name = "TFTP Request"
        elif logType == "11001": event_name = "NTP Monlist"
        elif logType == "12001": event_name = "VNC Connection"
        elif logType == "13001": event_name = "SNMP Command"
        elif logType == "14001": event_name = "RDP Connection"
        elif logType == "15001": event_name = "SIP Request"
        elif logType == "16001": event_name = "Git Clone Request"
        elif logType == "17001": event_name = "Redis Command"
        elif logType == "20001": event_name = "MongoDB Login"
        # Add more as needed

    # Construct display command
    displayCommand = "{0}:{1} > {2}:{3}  ".format(sourceIP, sourcePort, destIP, destPort)
    
    if sendTheEmail:
        displayCommand += f'\033[31;40m {event_name} \033[37;40m\n'
    else:
        displayCommand += '\033[32;40m Ignored \033[37;40m\n'

    # Optional: Remove /dev/tty1 write if running as a daemon/service
    # with open("/dev/tty1", "w") as f:
    #     f.write(displayCommand)
    print(displayCommand.strip())

    return sendTheEmail, event_name
#Investigate this return is resulting in any sendTheEmail's after this being invalid. 
#But commenting it is stopping emails

# very basic code to send a simple email to the defined recipient
def  SendEmail(emailText):
    try:
        emailMessage = EMAILTEMPLATE + emailText
        server = smtplib.SMTP(SMTP_SERVER,587)
        server.ehlo()
        server.starttls(context=context)
        server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.sendmail(SMTP_USERNAME, TO_ADDRESS, emailMessage)
        server.quit()
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

def get_last_position():
    if os.path.exists(POSITION_FILE):
        with open(POSITION_FILE, 'r') as f:
            try:
                return int(f.read().strip())
            except ValueError:
                return 0
    return 0

def save_position(pos):
    with open(POSITION_FILE, 'w') as f:
        f.write(str(pos))

# -------- Main Logic --------

last_pos = get_last_position()
current_size = os.path.getsize(LOGFILE)

# If log was rotated (file size reset), reset position to 0
if current_size < last_pos:
    print("Log file rotated detected. Resetting position.")
    last_pos = 0

localText = ""

#Display the logs neatly.
count = 0

with open(LOGFILE, 'r') as file2:
    file2.seek(last_pos)

    for line in file2:
        sourceIP   = findParam(line, "src_host")
        destIP     = findParam(line, "dst_host")
        destPort   = findParam(line, "dst_port")
        sourcePort = findParam(line, "src_port")
        logType    = findParam(line, "logtype")
        adjTime    = findParam(line, "local_time_adjusted")

        should_email, event_name = CheckLine(line.strip())
        
        if should_email:
            count += 1
            localText += "Event {}:\n\n".format(count)
            localText += "Type: {}\n".format(event_name)
            localText += "Src: {0}:{1}  >  Dest: {2}:{3} \n".format(sourceIP, sourcePort, destIP, destPort)
            localText += "Time: {}\n".format(adjTime)
            localText += "\n{}".format(line)
            localText += "=================================\n"
            
            #localText += f"Event {count}:\nSource IP: {sourceIP} > Dest: {destIP}:{destPort}\nTime: {adjTime}\n{line}\n"
        
    # Update the position to the current end of the file
    new_pos = file2.tell()
    save_position(new_pos)

#print(localText)

if count > 0:
    print(f"Found {count} new events. Sending email...")
    if SendEmail(localText):
        print("Email sent successfully!")
        # Only clear the log if email was sent successfully
        # OR: You can choose NOT to clear the log and just rely on the position pointer (safer)
        # If you want to clear the log to save space:
        # open(LOGFILE, 'w').close()
        # But then you must reset the position file to 0 too.
        # Recommendation: Don't clear the log, just rely on the position pointer.
    else:
        print("Email failed. Log not cleared.")
