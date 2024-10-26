#!/bin/sh
mkswap -U clear $1
swapon $1
