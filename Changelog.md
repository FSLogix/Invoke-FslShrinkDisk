# ChangeLog

## 2020 09 28

- Many improvements to cope with the underlying disk subsystem returning incomplete or non-existent objects when under stress
- New checking and remediation for pre-requisite services
- Introduced throttling of threads when the script is being run on too few cores for the threads specified
- Introduced better error messages
- Added better parameter validation

## 2020 08 12

- Removed unecessary partition resize from script
- Fixed Diskpart wasn't running against disks with spaces in the path
- Improved Shrink for legacy vhd disks making them more consistent
- Added better error reporting if the disk doesn't mount properly
- Improved file filtering so it doesn't pick up false positives