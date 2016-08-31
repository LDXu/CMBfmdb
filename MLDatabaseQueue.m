//
//  CLDatabaseQueue.m
//  CarLoan
//
//  Created by sml on 16/6/27.
//  Copyright © 2016年 sml. All rights reserved.
//

#import "MLDatabaseQueue.h"
//#import "CLUser.h"
//#import "CLPerson.h"
//#import "CLCustomer.h"
//#import "CLRole.h"
//#import "CLCheckRecord.h"
//#import "CLDepart.h"
//#import "CLCredit.h"
//#import "CLAccommodateRecord.h"
//#import "CLPrivilege.h"
//#import "CLFinancialState.h"
#import "CSOrder.h"
//#import "BSTeacher.h"
//#import "BSUser.h"
//#import "BSStudent.h"

#define AppHomePath     [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define DBPath [AppHomePath stringByAppendingPathComponent:@"XuBilldata.sqlite"]

//typedef void(^ExistOptin)(BOOL exist);
@implementation MLDatabaseQueue
static FMDatabaseQueue *_dbQueue;
static NSMutableArray *_sqlsForCreateTable;

+ (NSMutableArray *)sqlsForCreateTable{
    if (_sqlsForCreateTable == nil) {
        _sqlsForCreateTable = [NSMutableArray arrayWithCapacity:3];
        
        NSString *ordSql = [CSOrder ml_sqlForCreateTableWithPrimaryKey:@"id"];
       //        NSString *roleSql = [CLRole ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *cheack_recordSql = [CLCheckRecord ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *departSql = [CLDepart ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *creditSql = [CLCredit ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *accmmodate_recordSql = [CLAccommodateRecord ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *privilegeSql = [CLPrivilege ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        NSString *financialSql = [CLFinancialState ml_sqlForCreateTableWithPrimaryKey:@"id"];
//        
        [_sqlsForCreateTable addObject:ordSql];

//        [_sqlsForCreateTable addObject:roleSql];
//        [_sqlsForCreateTable addObject:cheack_recordSql];
//        [_sqlsForCreateTable addObject:departSql];
//        [_sqlsForCreateTable addObject:creditSql];
//        [_sqlsForCreateTable addObject:accmmodate_recordSql];
//        [_sqlsForCreateTable addObject:privilegeSql];
//        [_sqlsForCreateTable addObject:financialSql];
    }
    return _sqlsForCreateTable;
}

+ (FMDatabaseQueue *)dbQueue{
    return [self ml_databaseQueue];
}

+ (FMDatabaseQueue *)ml_databaseQueue{
    if (_dbQueue == nil) {
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:DBPath];
        [_dbQueue inDatabase:^(FMDatabase *db) {
            for (NSString *sql in [self sqlsForCreateTable]) {
                BOOL ok = [db executeUpdate:sql];
                if (ok == NO) {
                    NSLog(@"----NO:%@---",sql);
                }
            }
        }];
    }
    return _dbQueue;
}


@end
