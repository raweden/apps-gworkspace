/* LSFUpdater.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
 *
 * This file is part of the GNUstep Finder application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef LSF_UPDATER_H
#define LSF_UPDATER_H

#include <Foundation/Foundation.h>

@protocol LSFolderProtocol

- (void)setUpdater:(id)anObject;

- (oneway void)updaterDidEndAction;

- (oneway void)updaterError:(NSString *)err;

- (oneway void)addFoundPath:(NSString *)path;

- (oneway void)removeFoundPath:(NSString *)path;

- (NSString *)infoPath;

- (NSString *)foundPath;

- (BOOL)isOpen;
                          
@end


@protocol	DDBd

- (BOOL)dbactive;

- (oneway void)insertPath:(NSString *)path;

- (oneway void)insertDirectoryTreesFromPaths:(NSData *)info;

- (oneway void)removeTreesFromPaths:(NSData *)info;

- (NSData *)directoryTreeFromPath:(NSString *)path;

@end


@interface LSFUpdater: NSObject
{
  NSMutableArray *searchPaths;
  unsigned spathindex;
  
  NSMutableArray *directories;
  unsigned dirindex;
  unsigned dircounter;
  unsigned dircount;

  NSMutableArray *modules;  
  NSDictionary *searchCriteria;
  
  NSMutableArray *foundPaths;
  int fpathindex;
  
  NSDate *lastUpdate;
  NSDate *startSearch;
  unsigned autoupdate;
  NSTimeInterval updateInterval;
  NSTimer *autoupdateTmr;
  
  id <LSFolderProtocol> lsfolder;
  id ddbd;
  NSFileManager *fm;
  NSNotificationCenter *nc;
}

+ (void)newUpdater:(NSDictionary *)info;

- (id)initWithLSFolderInfo:(NSDictionary *)info;

- (void)setAutoupdate:(unsigned)value;

- (void)resetTimer;

- (void)notifyEndAction:(id)sender;

- (void)exitThread;


- (void)fastUpdate;

- (void)getFoundPaths;

- (void)checkFoundPaths;

- (void)updateSearchPath:(NSString *)srcpath;

- (BOOL)saveResults;


- (NSArray *)fullSearchInDirectory:(NSString *)dirpath;

- (BOOL)checkPath:(NSString *)path;

- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs;

- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs
       withModule:(id)module;

- (void)insertShorterPath:(NSString *)path 
                  inArray:(NSMutableArray *)array;

@end


@interface LSFUpdater (ddbd)

- (void)connectDDBd;

- (void)ddbdConnectionDidDie:(NSNotification *)notif;

- (void)ddbdInsertTrees;

- (void)ddbdInsertDirectoryTreesFromPaths:(NSArray *)paths;

- (NSArray *)ddbdGetDirectoryTreeFromPath:(NSString *)path;

- (void)ddbdRemoveTreesFromPaths:(NSArray *)paths;

@end


@interface LSFUpdater (scheduled)

- (void)searchInNextDirectory:(id)sender;

- (void)checkNextFoundPath;

@end

#endif // LSF_UPDATER_H








