# This file is part of Hopsworks
# Copyright (C) 2018, Logical Clocks AB. All rights reserved

# Hopsworks is free software: you can redistribute it and/or modify it under the terms of
# the GNU Affero General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.

# Hopsworks is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.

'''
Dependencies:
 Pydoop: 1.2.0
 kagent_utils: 0.1+
'''

__license__ = "AGPL v3"
__version__ = "0.1"

import os
import re
import time
import argparse
import ConfigParser
import logging.handlers

import pydoop.hdfs as hdfs

from kagent_utils import IntervalParser

BACKUP_OP = "backup"
DELETE_OP = "delete"
BACKUP_PERMISSIONS = 0700
ROLLED_LOG_REGEX = re.compile(".*\.log\.[1-9]+")

class LogFile:
    def __init__(self, dirpath, filename):
        self.filepath = os.path.join(dirpath, filename)
        self.filename = filename
        self.mtime = os.path.getmtime(self.filepath)

    def __str__(self):
        return "{0}: {1}".format(self.filepath, self.mtime)
    
def list_local_files(local_log_dir):
    log_files = []
    for dirpath, dirnames, filenames in os.walk(local_log_dir):
        for filename in filenames:
            if ROLLED_LOG_REGEX.match(filename):
                log_files.append(LogFile(dirpath, filename))
    return log_files

def load_checkpoint(checkpoint_file):
    LOGGER = logging.getLogger(__name__)
    if not os.path.isfile(checkpoint_file):
        LOGGER.debug("Checkpoint file does not exist")
        return -1
    with open(checkpoint_file, 'r') as fd:
        checkpoint = float(fd.readline())
        LOGGER.debug("Last checkpoint at {0}".format(time.ctime(checkpoint)))
        return checkpoint

def write_checkpoint(checkpoint_file):
    with open(checkpoint_file, 'w') as fd:
        fd.write(str(time.time()))

def get_remote_dir(log_file, remote_basedir):
    LOGGER = logging.getLogger(__name__)
    time_struct = time.gmtime(log_file.mtime)
    remote_dir = os.path.join(remote_basedir, str(time_struct.tm_year), str(time_struct.tm_mon))
    LOGGER.debug("Remote dir for {0} is {1}".format(log_file, remote_dir))
    return remote_dir

def remote_dir_exists(remote_dir):
    return hdfs.path.isdir(remote_dir)

def create_remote_dir(remote_dir):
    hdfs.mkdir(remote_dir)
    logging.getLogger(__name__).debug("Creating remote directory {0}".format(remote_dir))

def copy_file_2_remote_dir(remote_dir, log_file):
    LOGGER = logging.getLogger(__name__)
    suffix = time.strftime('%d-%m-%y_%H-%M-%S', time.gmtime(log_file.mtime))
    dest_filename = os.path.join(remote_dir, "{0}-{1}".format(log_file.filename, suffix))
    LOGGER.debug("Copying {0} to {1}".format(log_file.filepath, dest_filename))
    hdfs.put(log_file.filepath, dest_filename)
    LOGGER.debug("Copied {0} to HDFS".format(log_file.filepath))
    hdfs.chmod(dest_filename, BACKUP_PERMISSIONS)
    LOGGER.debug("Changed permissions for {0}".format(dest_filename))

def backup(config):
    LOGGER = logging.getLogger(__name__)
    remote_basedir = config.get('backup', 'remote-basedir')
    local_log_dir = config.get('backup', 'local-log-dir')
    checkpoint_file = config.get('backup', 'checkpoint')
    
    if not remote_dir_exists(remote_basedir):
        LOGGER.debug("Remote directory {0} does not exist, creating it".format(remote_basedir))
        create_remote_dir(remote_basedir)
        hdfs.chmod(remote_basedir, BACKUP_PERMISSIONS)
    log_files = list_local_files(local_log_dir)
    now = time.time()
    checkpoint = load_checkpoint(checkpoint_file)
    copied_log_files = {}
    for log_file in log_files:
        if log_file.mtime > checkpoint:
            remote_dir = get_remote_dir(log_file, remote_basedir)
            if not remote_dir_exists(remote_dir):
                create_remote_dir(remote_dir)
                LOGGER.debug("Created remote directory {0}".format(remote_dir))
            try:
                copy_file_2_remote_dir(remote_dir, log_file)
                copied_log_files[log_file] = remote_dir
            except Exception as ex:
                LOGGER.warn("Error while copying {0} - {1}".format(log_file, ex))

    LOGGER.debug("Finished copying, updating checkpoint")
    write_checkpoint(checkpoint_file)

    if not copied_log_files:
        LOGGER.debug("Did not copy any log file")
    else:
        for lf, rd in copied_log_files.iteritems():
            LOGGER.info("Copied file {0} to {1}".format(lf, rd))

    LOGGER.info("Finished copying files")

def walk_remotely(remote_path):
    LOGGER.debug("Walking {0}".format(remote_path))
    inodes = hdfs.lsl(remote_path, recursive=True)
    return inodes

def delete_files(remote_basedir, retention):
    inodes = walk_remotely(remote_basedir)
    now = time.time()
    deleted_files = []
    for inode in inodes:
        if now - inode['last_mod'] > retention and inode['kind'] == 'file':
            LOGGER.debug("Deleting file {0}".format(inode['path']))
            hdfs.rmr(inode['path'])
            deleted_files.append(inode['path'])
    return deleted_files

def clean_empty_dirs(remote_basedir):
    LOGGER = logging.getLogger(__name__)
    deleted_dirs = []
    ## Directory structure is {remote_basedir}/{year}/{month}
    year_dirs = hdfs.ls(remote_basedir)
    # Do an ls to find all month dirs
    for year_dir in year_dirs:
        month_dirs = hdfs.ls(hdfs.path.join(remote_basedir, year_dir))
        # Check to see if month dirs are empty
        month_dirs_deleted = 0
        for month_dir in month_dirs:
            files = hdfs.ls(hdfs.path.join(remote_basedir, year_dir, month_dir))
            if not files:
                LOGGER.debug("Directory {0} is empty, deleting it".format(month_dir))
                hdfs.rmr(month_dir)
                deleted_dirs.append(month_dir)
                month_dirs_deleted += 1

        if month_dirs_deleted == len(month_dirs):
            # Deleted all month sub-directories, so delete year directory too
            LOGGER.debug("Directory {0} is empty, deleting it".format(year_dir))
            hdfs.rmr(year_dir)
            deleted_dirs.append(year_dir)
    return deleted_dirs

def delete(config):
    LOGGER = logging.getLogger(__name__)
    remote_basedir = config.get('backup', 'remote-basedir')
    retention = config.get('delete', 'retention')
    interval_parser = IntervalParser()
    retention_sec = interval_parser.get_interval_in_s(retention)
    deleted_files = delete_files(remote_basedir, retention_sec)
    deleted_dirs = clean_empty_dirs(remote_basedir)

    if not deleted_files:
        LOGGER.debug("No log files deleted")
    else:
        [LOGGER.info("Deleted log file: {0}".format(f)) for f in deleted_files]

    if not deleted_dirs:
        LOGGER.debug("No empty dirs deleted")
    else:
        [LOGGER.info("Deleted empty dir {0}".format(f)) for f in deleted_dirs]
        
    LOGGER.info("Done deleting files")
    
def setup_logging(log_file, logging_level):
    logger = logging.getLogger(__name__)
    logger_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    logger_file_handler = logging.handlers.RotatingFileHandler(log_file, maxBytes=50000000, backupCount=5)
    logger_stream_handler = logging.StreamHandler()
    logger_file_handler.setFormatter(logger_formatter)
    logger_stream_handler.setFormatter(logger_formatter)
    logger.addHandler(logger_file_handler)
    logger.addHandler(logger_stream_handler)
    logger.setLevel(logging_level)
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Hops logs backup")
    parser.add_argument('-c', '--config', help='Configuration file')

    subparser = parser.add_subparsers(dest='operation', help='Operations')
    subparser.add_parser(BACKUP_OP, help='Move Hops log files to HDFS')
    subparser.add_parser(DELETE_OP, help='Delete old log files from HDFS')
    args = parser.parse_args()

    config = ConfigParser.ConfigParser()
    config.read(args.config)
    log_file = config.get('general', 'log-file')
    logging_level_str = config.get('general', 'logging-level')
    logging_level = getattr(logging, logging_level_str.upper(), None)
    if not isinstance(logging_level, int):
        raise ValueError("Invalid log level {0}".format(logging_level_str))
    setup_logging(log_file, logging_level)

    LOGGER = logging.getLogger(__name__)
    if args.operation == BACKUP_OP:
        LOGGER.debug("Performing BACKUP")
        backup(config)
    elif args.operation == DELETE_OP:
        LOGGER.debug("Performing DELETE")
        delete(config)
    else:
        LOGGER.error("Unknown operation {0}".format(args.operation))

