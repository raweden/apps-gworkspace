/* SearchResults.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep GWorkspace application
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "SearchResults.h"
#include "ResultsTableView.h"
#include "FSNTextCell.h"
#include "ResultsPathsView.h"
#include "Finder.h"
#include "FinderModulesProtocol.h"
#include "FSNode.h"
#include "FSNodeRep.h"
#include "GWFunctions.h"
#include "Dialogs/Dialogs.h"

#define CELLS_HEIGHT (28.0)

#define LSF_INFO(x) [x stringByAppendingPathComponent: @"lsf.info"]
#define LSF_FOUND(x) [x stringByAppendingPathComponent: @"lsf.found"]

static NSString *nibName = @"SearchResults";
static NSString *lsfname = @"LiveSearch.lsf";

@implementation SearchResults

- (void)dealloc
{
  [nc removeObserver: self];

  if (toolConn != nil) {
    if (searchtool != nil) {
      [searchtool terminate];
    }
    DESTROY (searchtool);    
    DESTROY (toolConn);
  }

  TEST_RELEASE (win);
  TEST_RELEASE (searchCriteria);
  TEST_RELEASE (foundObjects);
  TEST_RELEASE (searchPaths);
  RELEASE (elementsStr);
  DESTROY (conn);
        
  [super dealloc];
}

- (id)init
{
	self = [super init];

  if (self) {
    NSUserDefaults *defaults;
    id entry;
    NSRect r;
    int srh;
      
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }
        
    [win setFrameUsingName: @"search_results"];
    [win setDelegate: self];
    
    progView = [[ProgressView alloc] initWithFrame: NSMakeRect(0, 0, 16, 16)
                                   refreshInterval: 0.1];
    [(NSBox *)progBox setContentView: progView]; 
    RELEASE (progView);
    
    r = [[(NSBox *)dragIconBox contentView] frame];
    documentIcon = [[DocumentIcon alloc] initWithFrame: r searchResult: self];
    [(NSBox *)dragIconBox setContentView: documentIcon]; 
    RELEASE (documentIcon);
    
    [elementsLabel setStringValue: @""];
    ASSIGN (elementsStr, NSLocalizedString(@"elements", @""));
    
    [stopButt setImage: [NSImage imageNamed: @"stop_small"]];
    [stopButt setEnabled: NO];
    [restartButt setImage: [NSImage imageNamed: @"magnify_small"]];
    [restartButt setEnabled: NO];
    
    [splitView setDelegate: self];
    
    [resultsScroll setBorderType: NSBezelBorder];
    [resultsScroll setHasHorizontalScroller: YES];
    [resultsScroll setHasVerticalScroller: YES]; 
    
    r = [[resultsScroll contentView] frame];

    resultsView = [[ResultsTableView alloc] initWithFrame: r];
    [resultsView setDrawsGrid: NO];
    [resultsView setAllowsColumnSelection: NO];
    [resultsView setAllowsColumnReordering: YES];
    [resultsView setAllowsColumnResizing: YES];
    [resultsView setAllowsEmptySelection: YES];
    [resultsView setAllowsMultipleSelection: YES];
    [resultsView setRowHeight: CELLS_HEIGHT];
    [resultsView setIntercellSpacing: NSZeroSize];
    [resultsView sizeLastColumnToFit];
        
    nameColumn = [[NSTableColumn alloc] initWithIdentifier: @"name"];
    [nameColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [nameColumn setEditable: NO];
    [nameColumn setResizable: YES];
    [[nameColumn headerCell] setStringValue: NSLocalizedString(@"Name", @"")];
    [[nameColumn headerCell] setAlignment: NSLeftTextAlignment];
    [nameColumn setMinWidth: 80];
    [nameColumn setWidth: 140];
    [resultsView addTableColumn: nameColumn];
    RELEASE (nameColumn);
    
    parentColumn = [[NSTableColumn alloc] initWithIdentifier: @"parent"];
    [parentColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [parentColumn setEditable: NO];
    [parentColumn setResizable: YES];
    [[parentColumn headerCell] setStringValue: NSLocalizedString(@"Parent", @"")];
    [[parentColumn headerCell] setAlignment: NSLeftTextAlignment];
    [parentColumn setMinWidth: 80];
    [parentColumn setWidth: 90];
    [resultsView addTableColumn: parentColumn];
    RELEASE (parentColumn);

    dateColumn = [[NSTableColumn alloc] initWithIdentifier: @"date"];
    [dateColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [dateColumn setEditable: NO];
    [dateColumn setResizable: YES];
    [[dateColumn headerCell] setStringValue: NSLocalizedString(@"Date Modified", @"")];
    [[dateColumn headerCell] setAlignment: NSLeftTextAlignment];
    [dateColumn setMinWidth: 80];
    [dateColumn setWidth: 90];
    [resultsView addTableColumn: dateColumn];
    RELEASE (dateColumn);

    sizeColumn = [[NSTableColumn alloc] initWithIdentifier: @"size"];
    [sizeColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [sizeColumn setEditable: NO];
    [sizeColumn setResizable: YES];
    [[sizeColumn headerCell] setStringValue: NSLocalizedString(@"Size", @"")];
    [[sizeColumn headerCell] setAlignment: NSLeftTextAlignment];
    [sizeColumn setMinWidth: 50];
    [sizeColumn setWidth: 50];
    [resultsView addTableColumn: sizeColumn];
    RELEASE (sizeColumn);

    kindColumn = [[NSTableColumn alloc] initWithIdentifier: @"kind"];
    [kindColumn setDataCell: AUTORELEASE ([[FSNTextCell alloc] init])];
    [kindColumn setEditable: NO];
    [kindColumn setResizable: YES];
    [[kindColumn headerCell] setStringValue: NSLocalizedString(@"Kind", @"")];
    [[kindColumn headerCell] setAlignment: NSLeftTextAlignment];
    [kindColumn setMinWidth: 80];
    [kindColumn setWidth: 80];
    [resultsView addTableColumn: kindColumn];
    RELEASE (kindColumn);

    [resultsScroll setDocumentView: resultsView];
    RELEASE (resultsView);
    
    [self setColumnsSizes];

    [resultsView setDataSource: self]; 
    [resultsView setDelegate: self];
    [resultsView setTarget: self];
    [resultsView setDoubleAction: @selector(doubleClickOnResultsView:)];

    foundObjects = [NSMutableArray new];

    defaults = [NSUserDefaults standardUserDefaults];
    
    entry = [defaults stringForKey: @"sorting_order"];
    if (entry) {
      [self setCurrentOrder: [entry intValue]];
    } else {
      [self setCurrentOrder: FSNInfoNameType];
    }

    finder = [Finder finder];
        
    r = [pathsScroll frame];
    srh = [finder searchResultsHeight];
    
    if (srh != 0) {
      r.size.height = srh;
      [pathsScroll setFrame: r];
    } 
        
    [pathsScroll setBorderType: NSBezelBorder];
    [pathsScroll setHasHorizontalScroller: NO];
    [pathsScroll setHasVerticalScroller: YES]; 

    r = [[pathsScroll contentView] frame];
    pathsView = [[ResultsPathsView alloc] initWithFrame: r];
    [pathsScroll setDocumentView: pathsView];
    RELEASE (pathsView);
        
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver: self
           selector: @selector(fileSystemDidChange:) 
               name: @"GWFileSystemDidChangeNotification"
             object: nil];    
  }
  
	return self;
}

- (void)activateForSelection:(NSArray *)selection
          withSearchCriteria:(NSDictionary *)criteria
                   recursive:(BOOL)rec
{
  NSString *cname;
  NSArray *paths;
  NSString *cmd;

  [win makeKeyAndOrderFront: nil];
  visibleRows = (int)([resultsScroll frame].size.height / CELLS_HEIGHT + 1);
  ASSIGN (searchPaths, selection);
  ASSIGN (searchCriteria, criteria);
  recursive = rec;
  
  cname = [NSString stringWithFormat: @"search_%i", [self memAddress]];

  if (conn == nil) {
    conn = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSPort port] 
																			      sendPort: nil];
    [conn setRootObject: self];
    [conn registerName: cname];
    [conn setDelegate: self];

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
  }

  if (toolConn != nil) {
    if (searchtool != nil) {
      [searchtool terminate];
    }
        
    DESTROY (searchtool);
    
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: toolConn];
    
    [toolConn invalidate];
    DESTROY (toolConn);
  }

  searchtool = nil;
  searching = YES;  

  [NSTimer scheduledTimerWithTimeInterval: 5.0 
						                       target: self
                                 selector: @selector(checkSearchTool:) 
																 userInfo: nil 
                                  repeats: NO];

  paths = NSSearchPathForDirectoriesInDomains(GSToolsDirectory, NSSystemDomainMask, YES);
  cmd = [[paths objectAtIndex: 0] stringByAppendingPathComponent: @"searchtool"];
                                          
  [NSTask launchedTaskWithLaunchPath: cmd 
                           arguments: [NSArray arrayWithObject: cname]];
}

- (BOOL)connection:(NSConnection *)ancestor 
								shouldMakeNewConnection:(NSConnection *)newConn
{
	if (ancestor == conn) {
    ASSIGN (toolConn, newConn);
  	[toolConn setDelegate: self];
    
  	[nc addObserver: self 
					 selector: @selector(connectionDidDie:)
	    				 name: NSConnectionDidDieNotification 
             object: toolConn];
	}
		
  return YES;
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: diedconn];

  if ((diedconn == conn) || (toolConn && (diedconn == toolConn))) {
    DESTROY (searchtool);
    DESTROY (toolConn);
    
    if (diedconn == conn) {
      DESTROY (conn);
    } 
    
    if (searching) {
      [self endOfSearch];
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"the search tool connection died!", @""), 
                      NSLocalizedString(@"Continue", @""), 
                      nil, 
                      nil);
    }
  }
}

- (void)checkSearchTool:(id)sender
{
  if (searching && (searchtool == nil)) {
    [self endOfSearch];
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"unable to launch the search task.", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
  }
}

- (oneway void)registerSearchTool:(id)tool
{
  NSDictionary *srcdict = [NSDictionary dictionaryWithObjectsAndKeys: 
                    searchPaths, @"paths", searchCriteria, @"criteria", 
                     [NSNumber numberWithBool: recursive], @"recursion", nil];
  NSData *info = [NSArchiver archivedDataWithRootObject: srcdict];

  [stopButt setEnabled: YES];
  [restartButt setEnabled: NO];
  [progView start];
  
  [tool setProtocolForProxy: @protocol(SearchToolProtocol)];
  searchtool = (id <SearchToolProtocol>)[tool retain];
  [searchtool searchWithInfo: info];  
}
                            
- (void)nextResult:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(pool);
  FSNode *node = [FSNode nodeWithPath: path];

  [foundObjects addObject: node];

  if ([foundObjects count] <= visibleRows) {
    [resultsView noteNumberOfRowsChanged];
  }

  [elementsLabel setStringValue: [NSString stringWithFormat: @"%i %@", 
                                          [foundObjects count], elementsStr]];
  RELEASE (pool);
}

- (void)endOfSearch
{
  [stopButt setEnabled: NO];
  [restartButt setEnabled: YES];
  [progView stop];
  searching = NO;
  
  if (searchtool) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: toolConn];
    [searchtool terminate];
    DESTROY (searchtool);
    DESTROY (toolConn);
  }

  [self updateShownData];
}

- (BOOL)searching
{
  return searching;
}

- (IBAction)stopSearch:(id)sender
{
  if (searchtool) {
    [searchtool stop];
  }
}

- (IBAction)restartSearch:(id)sender
{
  if (searchtool == nil) {
    [foundObjects removeAllObjects];
    [resultsView reloadData];
    [self activateForSelection: searchPaths
            withSearchCriteria: searchCriteria
                     recursive: recursive];
  }
}

- (void)updateShownData
{
  SEL sortingSel;
  NSTableColumn *column;

  switch(currentOrder) {
    case FSNInfoNameType:
      sortingSel = @selector(compareAccordingToName:);
      column = nameColumn;
      break;
    case FSNInfoParentType:
      sortingSel = @selector(compareAccordingToParent:);
      column = parentColumn;
      break;
    case FSNInfoKindType:
      sortingSel = @selector(compareAccordingToKind:);
      column = kindColumn;
      break;
    case FSNInfoDateType:
      sortingSel = @selector(compareAccordingToDate:);
      column = dateColumn;
      break;
    case FSNInfoSizeType:
      sortingSel = @selector(compareAccordingToSize:);
      column = sizeColumn;
      break;
    default:
      sortingSel = @selector(compareAccordingToName:);
      column = nameColumn;
      break;
  }

  [foundObjects sortUsingSelector: sortingSel];
  [resultsView setHighlightedTableColumn: column];
  [resultsView reloadData];
}

- (void)setCurrentOrder:(FSNInfoType)order
{
  currentOrder = order;
}

- (NSArray *)selectedObjects
{
  NSMutableArray *selected = [NSMutableArray array];
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;
  
  while ((row = [enumerator nextObject])) {
	  FSNode *node = [foundObjects objectAtIndex: [row intValue]];
    if ([node isValid]) {
      [selected addObject: node];
    } else {
      [foundObjects removeObject: node];
      [resultsView noteNumberOfRowsChanged];
    }
  }

  return selected;  
}

- (void)doubleClickOnResultsView:(id)sender
{
  [finder openFoundSelection: [self selectedObjects]];
}

- (void)selectObjects:(NSArray *)objects
{
  int i;
  
  for (i = 0; i < [objects count]; i++) {
    FSNode *node = [objects objectAtIndex: i];
    int index = [foundObjects indexOfObject: node];
    
    [resultsView selectRow: index byExtendingSelection: (i != 0)];
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif object];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *deletedObjects = [NSMutableArray array];
  int i, j;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		files = [info objectForKey: @"origfiles"];
  }	
  
  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fullPath = [source stringByAppendingPathComponent: fname];
      
      for (j = 0; j < [foundObjects count]; j++) {
        FSNode *node = [foundObjects objectAtIndex: j];
        NSString *path = [node path];
      
        if ([fullPath isEqual: path]) {
          [deletedObjects addObject: node];
        }
      }
    }
    
  } else if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    for (i = 0; i < [foundObjects count]; i++) {
      FSNode *node = [foundObjects objectAtIndex: i];
      NSString *path = [node path];

      if ([source isEqual: path]) {
        [deletedObjects addObject: node];
      }
    }
  }
  
  if ([deletedObjects count]) {
    for (i = 0; i < [deletedObjects count]; i++) {
      [foundObjects removeObject: [deletedObjects objectAtIndex: i]];
    }
    
    [resultsView deselectAll: self];
    [self updateShownData];
  }
}

- (void)setColumnsSizes
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *columnsDict = [defaults objectForKey: @"columns_sizes"];

  if (columnsDict) {
    NSArray *columns = [resultsView tableColumns];
    NSMutableArray *sortedCols = [NSMutableArray array];
    NSArray *keys = [columnsDict keysSortedByValueUsingSelector: @selector(compareColInfo:)];
    int i;

    for (i = 0; i < [keys count]; i++) {
      NSString *identifier = [keys objectAtIndex: i];
      int col = [resultsView columnWithIdentifier: identifier];
      NSTableColumn *column = [columns objectAtIndex: col];
      NSDictionary *cdict = [columnsDict objectForKey: identifier];
      float width = [[cdict objectForKey: @"width"] floatValue];

      [column setWidth: width];
      [sortedCols insertObject: column atIndex: [sortedCols count]];
    }

    for (i = 0; i < [sortedCols count]; i++) {
      [resultsView removeTableColumn: [sortedCols objectAtIndex: i]];
    }            

    for (i = 0; i < [sortedCols count]; i++) {
      [resultsView addTableColumn: [sortedCols objectAtIndex: i]];
    }    
  }
}

- (void)saveColumnsSizes
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *columnsDict = [NSMutableDictionary dictionary];
  NSArray *columns = [resultsView tableColumns];
  int i;
        
  for (i = 0; i < [columns count]; i++) {
    NSTableColumn *column = [columns objectAtIndex: i];
    NSString *identifier = [column identifier];
    NSNumber *cwidth = [NSNumber numberWithFloat: [column width]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject: [NSNumber numberWithInt: i] forKey: @"position"];
    [dict setObject: cwidth forKey: @"width"];
    
    [columnsDict setObject: dict forKey: identifier];
  }

  [defaults setObject: columnsDict forKey: @"columns_sizes"];
  [defaults synchronize];
}

- (NSWindow *)win
{
  return win;
}

- (unsigned long)memAddress
{
  return (unsigned long)self;
}

- (void)createLiveSearchFolderAtPath:(NSString *)path
{
  SympleDialog *dialog;
  NSString *folderName;
	NSArray *contents;
  int result;

	dialog = [[SympleDialog alloc] initWithTitle: NSLocalizedString(@"New Live Search", @"") 
                                      editText: lsfname
                                   switchTitle: nil];
  AUTORELEASE (dialog);
	[dialog center];
  [dialog makeKeyWindow];
  [dialog orderFrontRegardless];

  result = [dialog runModal];
	if (result != NSAlertDefaultReturn) {
    return;
  }  

  folderName = [dialog getEditFieldText];

  if ([folderName length] == 0) {
		NSString *msg = NSLocalizedString(@"No name supplied!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

  contents = [fm directoryContentsAtPath: path];
  
  if ([contents containsObject: folderName] == NO) {
    NSNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    NSMutableDictionary *notifDict = [NSMutableDictionary dictionary];		
    NSString *lsfpath = [path stringByAppendingPathComponent: folderName];
    BOOL lsfdone = YES;

    [notifDict setObject: @"GWorkspaceCreateDirOperation" 
                  forKey: @"operation"];	
    [notifDict setObject: path forKey: @"source"];	
    [notifDict setObject: path forKey: @"destination"];	
    [notifDict setObject: [NSArray arrayWithObject: folderName] 
                  forKey: @"files"];	

	  [dnc postNotificationName: @"GWFileSystemWillChangeNotification"
	 								     object: nil 
                     userInfo: notifDict];

    if ([fm createDirectoryAtPath: lsfpath attributes: nil]) {
      NSMutableArray *foundPaths = [NSMutableArray array];
      NSMutableDictionary *lsfdict = [NSMutableDictionary dictionary];
      int i;
   
      for (i = 0; i < [foundObjects count]; i++) {
        [foundPaths addObject: [[foundObjects objectAtIndex: i] path]];
      }
   
      [lsfdict setObject: searchPaths forKey: @"searchpaths"];	
      [lsfdict setObject: searchCriteria forKey: @"criteria"];	
      [lsfdict setObject: [NSNumber numberWithBool: recursive]
                  forKey: @"recursion"];	
      [lsfdict setObject: [[NSDate date] description] forKey: @"lastupdate"];	
   
      lsfdone = [lsfdict writeToFile: LSF_INFO(lsfpath) atomically: YES];
      lsfdone = [foundPaths writeToFile: LSF_FOUND(lsfpath) atomically: YES];
    } else {
      lsfdone = NO;
    }

    if (lsfdone) {
      [finder addLiveSearchFolderWithPath: lsfpath createIndex: YES];
    } else {
      NSString *msg = NSLocalizedString(@"can't create the Live Search folder", @"");
      NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);  
    } 

	  [dnc postNotificationName: @"GWFileSystemDidChangeNotification"
	 						         object: nil 
                     userInfo: notifDict];  
  } else {
    NSString *msg = [NSString stringWithFormat: @"a file named \"%@\" already exists.\nPlease rename it.", folderName];
    NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);  
  }
}

- (BOOL)windowShouldClose:(id)sender
{
	return !searching;
}

- (void)windowDidMove:(NSNotification *)aNotification
{
  [win saveFrameUsingName: @"search_results"];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  NSArray *selected = [self selectedObjects];

  if ([selected count]) {
    [finder foundSelectionChanged: [FSNode pathsOfNodes: selected]];
  }
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
  [defaults setObject: [NSNumber numberWithInt: currentOrder] 
               forKey: @"sorting_order"];
  [defaults synchronize];
  
  [self saveColumnsSizes];
  
  [win saveFrameUsingName: @"search_results"];
  [finder resultsWindowWillClose: self];
}


//
// NSSplitView delegate methods
//
#define MIN_PATHS_H 40
#define MIN_RESULTS_H 80

- (void)splitView:(NSSplitView *)sender 
                  resizeSubviewsWithOldSize:(NSSize)oldSize
{
  NSRect spBounds = [splitView bounds];
  float dvt = [splitView dividerThickness];
  float ptsHeight = NSHeight([pathsScroll frame]);
  float	resHeight;
  NSRect newFrame;
  
  if ((ptsHeight + dvt) > (NSHeight(spBounds) - MIN_RESULTS_H)) {
    ptsHeight = MIN_PATHS_H;
  }
  
  resHeight = NSHeight(spBounds) - ptsHeight - dvt;
  
  newFrame = NSMakeRect(0, 0, NSWidth(spBounds), resHeight);
  [resultsScroll setFrame: newFrame];

  newFrame = NSMakeRect(0, resHeight + dvt, NSWidth(spBounds), ptsHeight);
  [pathsScroll setFrame: newFrame];
  
  [resultsView sizeLastColumnToFit];
  
  [finder setSearchResultsHeight: ceil(NSHeight([pathsScroll frame]))];  
}

- (float)splitView:(NSSplitView *)sender 
            constrainMaxCoordinate:(float)proposedMax 
                       ofSubviewAt:(int)offset
{
  float spHeight = NSHeight([splitView bounds]);
  float dvt = [splitView dividerThickness];

  if (proposedMax > (spHeight - dvt - MIN_PATHS_H)) {
    return (spHeight - dvt - MIN_PATHS_H);
  }
  
  return proposedMax;
}

- (float)splitView:(NSSplitView *)sender 
            constrainMinCoordinate:(float)proposedMin 
                       ofSubviewAt:(int)offset
{
  if (proposedMin < MIN_RESULTS_H) {
    return MIN_RESULTS_H;
  }

  return proposedMin;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  visibleRows = (int)([resultsScroll frame].size.height / CELLS_HEIGHT + 1);
  if ([foundObjects count] <= visibleRows) {
    [resultsView noteNumberOfRowsChanged];
  }
  [finder setSearchResultsHeight: ceil(NSHeight([pathsScroll frame]))]; 
}


//
// NSTableDataSource protocol
//
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [foundObjects count];
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  FSNode *node = [foundObjects objectAtIndex: rowIndex];
  
  if (aTableColumn == nameColumn) {
    return [node name];
  } else if (aTableColumn == parentColumn) {
    return [[node parentPath] lastPathComponent];
  } else if (aTableColumn == dateColumn) {
    return [node modDateDescription];
  } else if (aTableColumn == sizeColumn) {
    return [node sizeDescription];
  } else if (aTableColumn == kindColumn) {
    return [node typeDescription];
  }
    
  return [NSString string];
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  NSMutableArray *paths = [NSMutableArray array];
  NSMutableArray *parentPaths = [NSMutableArray array];
  int i;

  for (i = 0; i < [rows count]; i++) {
    int index = [[rows objectAtIndex: i] intValue];
    FSNode *node = [foundObjects objectAtIndex: index];
    NSString *parentPath = [node parentPath];
    
    if (([parentPaths containsObject: parentPath] == NO) && (i != 0)) {
      NSString *msg = NSLocalizedString(@"You can't move objects with multiple parent paths!", @"");
      NSRunAlertPanel(nil, msg, NSLocalizedString(@"Continue", @""), nil, nil);
      return NO;
    }
    
    if ([node isValid]) {
      [paths addObject: [node path]];
      [parentPaths addObject: parentPath];
    }
  }

  [pboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
                                           owner: nil];
  [pboard setPropertyList: paths forType: NSFilenamesPboardType];

  return YES;
}


//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSArray *selected = [self selectedObjects];

  [pathsView showComponentsOfSelection: selected];
  
  if ([selected count]) {
    [finder foundSelectionChanged: [FSNode pathsOfNodes: selected]];
  }
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(int)rowIndex
{
  if (aTableColumn == nameColumn) {
    FSNTextCell *cell = (FSNTextCell *)[nameColumn dataCell];
    FSNode *node = [foundObjects objectAtIndex: rowIndex];

    [cell setIcon: [[FSNodeRep sharedInstance] iconOfSize: 24 forNode: node]];
    
  } else if (aTableColumn == dateColumn) {
    [(FSNTextCell *)[dateColumn dataCell] setDateCell: YES];
  }
}

- (void)tableView:(NSTableView *)tableView 
            mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
  NSString *newOrderStr = [tableColumn identifier]; 
  FSNInfoType newOrder = FSNInfoNameType;

  if ([newOrderStr isEqual: @"name"]) {
    newOrder = FSNInfoNameType;
  } else if ([newOrderStr isEqual: @"parent"]) {
    newOrder = FSNInfoParentType;
  } else if ([newOrderStr isEqual: @"kind"]) {
    newOrder = FSNInfoKindType;
  } else if ([newOrderStr isEqual: @"date"]) {
    newOrder = FSNInfoDateType;
  } else if ([newOrderStr isEqual: @"size"]) {
    newOrder = FSNInfoSizeType;
  }

  if (newOrder != currentOrder) {
    currentOrder = newOrder;
    
    [self updateShownData];
  }

  [tableView setHighlightedTableColumn: tableColumn];
}

// ResultsTableView
- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows
{
  if ([dragRows count] > 1) {
    return [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: 24];
  } else {
    int index = [[dragRows objectAtIndex: 0] intValue];
    FSNode *node = [foundObjects objectAtIndex: index];
    
    return [[FSNodeRep sharedInstance] iconOfSize: 24 forNode: node];
  }

  return nil;
}

@end


@implementation ProgressView

#define IMAGES 8

- (void)dealloc
{
  RELEASE (images);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    int i;
  
    images = [NSMutableArray new];
  
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%d.tiff", i];
      [images addObject: [NSImage imageNamed: imname]];    
    }
  
    rfsh = refresh;
    animating = NO;
  }

  return self;
}

- (void)start
{
  index = 0;
  animating = YES;
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						            target: self selector: @selector(animate:) 
																					userInfo: nil repeats: YES];
}

- (void)stop
{
  animating = NO;
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
  [self setNeedsDisplay: YES];
}

- (void)animate:(id)sender
{
  [self setNeedsDisplay: YES];
  index++;
  if (index == [images count]) {
    index = 0;
  }
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (animating) {
    [[images objectAtIndex: index] compositeToPoint: NSMakePoint(0, 0) 
                                          operation: NSCompositeSourceOver];
  }
}

@end



@implementation DocumentIcon

- (void)dealloc
{
  RELEASE (icon);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
       searchResult:(id)sres
{
  self = [super initWithFrame: frameRect];

  if (self) {
    ASSIGN (icon, [NSImage imageNamed: @"DragableDocument"]);
    searchResult = sres;
  }

  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  BOOL startdnd = NO;
  int dragdelay = 0;
  NSPoint p = [theEvent locationInWindow];
  
  p = [self convertPoint: p fromView: nil];
  
	if ([theEvent clickCount] == 1) {   
    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        [[self window] postEvent: nextEvent atStart: NO];
        break;

      } else if ([nextEvent type] == NSLeftMouseDragged) {
	      if (dragdelay < 5) {
          dragdelay++;
        } else {        
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: theEvent];    
    } 
  }              
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  [icon compositeToPoint: NSMakePoint(2, 2) 
               operation: NSCompositeSourceOver];
}

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSArray *dndtypes = [NSArray arrayWithObject: @"GWLSFolderPboardType"];
  NSMutableDictionary *pbDict = [NSMutableDictionary dictionary];
  NSData *pbData = nil;
  
  [pb declareTypes: dndtypes owner: nil]; 
    
  [pbDict setObject: [NSArray arrayWithObject: lsfname] 
             forKey: @"paths"];  
  [pbDict setObject: [NSNumber numberWithUnsignedLong: [searchResult memAddress]] 
             forKey: @"sender"];  
  
  pbData = [NSArchiver archivedDataWithRootObject: pbDict];
  [pb setData: pbData forType: @"GWLSFolderPboardType"];

  [self dragImage: icon
               at: NSZeroPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: YES];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
  return YES;
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
           deposited:(BOOL)flag
{
  [self setNeedsDisplay: YES];
}

@end 
