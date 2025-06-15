# linuxsetup
Bash scripts to setup a Cloud Drive like solution

## Fun stuff with Linux File Servers
The goal is to create Bash scripts that
- Make automated backups
- Create webdrives like OneDrive, Dropbox and Google Drive, but locally
- Use SSH to do remote desktop sessions, mount directories from the local server as a drive to the client machine
- Allow me to work on any machine seamlessly, with the same files and setup

## Fun stuff with Linux
These scripts are tested, and good for home usem, but not production ready.

## A repository for working solutions
There are so many blogs and forum discussions, that it is really hard to decide what direction is proper in anything.
Overall:
- Linux offers a lot of solutions out of the box, if you understand what the base filosophy is behind the system itself.
- Many "solutions" offered require the installation of libraries you do not need to install to begin with.

## A log of experiences
For instance: "How do you create a secure mountable network drive?" has many possible answers, including using WebDav, Samba and so on.
- I share what works for me, including what I tried and why I abandoned certain routes. Mostly for myself, but it might help you as well.

## Goals
My goals are the following:

1: To setup a cluster of solutions that allow me to
- Share and access folders over the local network, so I can use any machine to acces my data from anywhere.
- Make automated backups of all my work, like OneDrive does, so that I don't have to bother where what file is.
- Automatically secure my data from ransomware, by having my servers creating read-only archives
- Automatically secure sensitive data, using automated data encryption on specific folders
- Have a Apple Time Machine like backups and version control, stored in slots of weeks, months, hours and days if needed.

  
