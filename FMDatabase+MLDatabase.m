//
//  FMDatabase-MLDatabase.m
//  CarLoan
//
//  Created by sml on 16/7/6.
//  Copyright © 2016年 sml. All rights reserved.
//

#import "FMDatabase+MLDatabase.h"

@implementation FMDatabase (CLDatabase)
#define AppHomePath     [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define DBPath [AppHomePath stringByAppendingPathComponent:@"XuBilldata.sqlite"]
#pragma mark -- 无PrimaryKey
- (void )ml_saveDataWithModel:(id )model  option:(SaveOption )option{
    [self ml_saveDataWithModel:model primaryKey:MLDB_PrimaryKey option:option];
}

- (void)ml_deleteDataWithModel:(id )model  option:(DeleteOption )option{
    [self ml_deleteDataWithModel:model primaryKey:MLDB_PrimaryKey option:option];
}

- (id )ml_excuteDataWithModel:(id )model  option:(ExcuteOption )option{
    return [self ml_excuteDataWithModel:model primaryKey:MLDB_PrimaryKey option:option];
}

- (void)ml_excuteDatasWithModel:(id )model  option:(AllModelsOption )option{
    [self ml_excuteDatasWithModel:model primaryKey:MLDB_PrimaryKey option:option];
}

#pragma mark -- 有PrimaryKey
- (void)ml_exsitInDatabaseForModel:(id )model primaryKey:(NSString *)primaryKey option:(ExistExcuteOption )option{
    if (!primaryKey) primaryKey = MLDB_PrimaryKey;
    
    id primary_keyValue = nil;
    if ([[model class] ml_primaryKey]) {
        primary_keyValue = [model valueForKey:[[model class] ml_primaryKey]];
        primaryKey = MLDB_PrimaryKey;
    }else{
        primary_keyValue = [model valueForKey:primaryKey];
    }
    FMResultSet *set = [self executeQuery:[NSString stringWithFormat:@"select * from %@ where %@ = %@ ;",NSStringFromClass([model class]),primaryKey,primary_keyValue]];
    if (option) {
        if ([set next]) {
            option(YES);
        } else {
            option(NO);
        }
        [set close];
    }
}

- (void)ml_insertDataWithModel:(id )model primaryKey:(NSString *)primaryKey option:(InsertOption )option {
    __block NSString *sql1 = [NSString stringWithFormat:@"insert into %@ (",NSStringFromClass([model class])];
    __block NSString *sql2 = [NSString stringWithFormat:@")  values  ("];
    //获取模型的属性名和属性类型
    [[model class] ml_objectIvar_nameAndIvar_typeWithOption:^(MLDatabaseRuntimeIvar *ivar) {
        NSString *ivar_name = ivar.name;
        NSInteger ivar_type = ivar.type;
        if (ivar_type == RuntimeObjectIvarTypeObject) {
            //先取值出来
            id value = [model valueForKey:ivar_name];
            
            if ([[model class] ml_replacedKeyFromDictionaryWhenPropertyIsObject]) {
                NSDictionary *dict = [[model class] ml_replacedKeyFromDictionaryWhenPropertyIsObject];
                if ([dict objectForKey:ivar_name]) {
                    // 递归调用
                    if (value) {
                        //[self ml_insertDataWithModel:value primaryKey:MLDB_PrimaryKey option:nil];
                        [self ml_saveDataWithModel:value primaryKey:MLDB_PrimaryKey option:nil];
                    }
                    //拼接外键
                    id subValue = [value valueForKey:primaryKey];
                    value = subValue;
                    ivar_name = [dict objectForKey:ivar_name];
                    ivar_type = RuntimeObjectIvarTypeOther;
                    sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%ld,",[value longValue]]];
                }
            }
            if ([[model class] ml_propertyIsInstanceOfArray] && [[[model class] ml_propertyIsInstanceOfArray] objectForKey:ivar_name]) {
                NSArray *arr = value;
                NSMutableArray *arrm = [NSMutableArray arrayWithCapacity:arr.count];
                for (id model in arr) {
                    [arrm addObject:[model mj_keyValues]];
                }
                ivar_type = RuntimeObjectIvarTypeArray;
                sql2 = [sql2 stringByAppendingString:@"'"];
                sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@",arrm.mj_JSONString]];
                sql2 = [sql2 stringByAppendingString:@"',"];
            }else if ([[model class] ml_propertyIsInstanceOfData] && [[[model class] ml_propertyIsInstanceOfData] objectForKey:ivar_name]) {
                NSData *data = value;
                ivar_type = RuntimeObjectIvarTypeData;
                sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@,",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]]];
            }else if ([[model class] ml_propertyIsInstanceOfImage] && [[[model class] ml_propertyIsInstanceOfImage] objectForKey:ivar_name]){
                ivar_type = RuntimeObjectIvarTypeImage;
                NSString *timeSince1970 = [NSString stringForTimeSince1970];
                UIImage *image = [model valueForKey:ivar_name];
                [UIImagePNGRepresentation(image) writeToFile:[self fullPathWithFileName:timeSince1970] atomically:YES];
                //这里只需要存储时间戳的字符串，取值时需要拼接
                sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@,",timeSince1970]];
            }
            if (ivar_type == RuntimeObjectIvarTypeObject) {
                sql2 = [sql2 stringByAppendingString:@"'"];
                sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@",value]];
                sql2 = [sql2 stringByAppendingString:@"',"];
            }
        }
        else if (ivar_type == RuntimeObjectIvarTypeDoubleAndFloat){
            NSNumber *doubleNumber = [model valueForKey:ivar_name];
            sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@,",doubleNumber]];
        }else if (ivar_type == RuntimeObjectIvarTypeArray){
            NSArray *arr = [model valueForKey:ivar_name];
            NSMutableArray *arrm = [NSMutableArray arrayWithCapacity:arr.count];
            for (id model in arr) {
                [arrm addObject:[model mj_keyValues]];
            }
            ivar_type = RuntimeObjectIvarTypeArray;
            sql2 = [sql2 stringByAppendingString:@"'"];
            sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@",arrm.mj_JSONString]];
            sql2 = [sql2 stringByAppendingString:@"',"];
        }else if (ivar_type == RuntimeObjectIvarTypeData){
            NSData *data = [model valueForKey:ivar_name];
            NSString *dataStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%@,",dataStr]];
            
        }else{
            id value = [model valueForKey:ivar_name];
            sql2 = [sql2 stringByAppendingString:[NSString stringWithFormat:@"%ld,",[value longValue]]];
        }
        
        /** 检测是否是表主键 */
        MLDB_EqualsPrimaryKey(ivar_name);
        /** 所有情况sql1的拼接都一样 */
        sql1 = [sql1 stringByAppendingString:[NSString stringWithFormat:@"%@,",ivar_name]];
    }];
    sql1 = [sql1 substringToIndex:sql1.length - 1];
    sql2 = [sql2 substringToIndex:sql2.length - 1];
    sql2 = [sql2 stringByAppendingString:@");"];
    sql1 = [sql1 stringByAppendingString:sql2];
    
    if ([self executeUpdate:sql1]) {
        NSLog(@"---insertDataWithModel:YES----");
        if (option) option(YES);
    }else{
        NSLog(@"---insertDataWithModel:NO----");
        if (option) option(NO);
    }
}

- (void)ml_updateDataWithModel:(id) model primaryKey:(NSString *)primaryKey optiin:(UpdateOption )option{
    NSString *table = NSStringFromClass([model class]);
    NSString *model_primaryKey = [primaryKey copy];
    __block NSString *initSql = [NSString stringWithFormat:@"update %@ set ",table];;
    if ([[model class] ml_primaryKey]) {
        model_primaryKey = [[model class] ml_primaryKey];
    }else{
        model_primaryKey = MLDB_PrimaryKey;
    }
    NSString *sql2 = [NSString stringWithFormat:@" where %@ = %@ ;",primaryKey,[model valueForKey:model_primaryKey]];
    [[model class] ml_objectIvar_nameAndIvar_typeWithOption:^(MLDatabaseRuntimeIvar *ivar) {
        [[model class] ml_replaceKeyWithIvarName:ivar.name ivar_type:ivar.type option:^(MLDatabaseRuntimeIvar *ivar) {
            NSString *ivar_name = ivar.name;
            NSInteger ivar_type = ivar.type;
            id value = nil;
            if (ivar_type == RuntimeObjectIvarTypeObject) {
                value = [model valueForKey:ivar_name];
                if (value) {
                    initSql = [initSql stringByAppendingString:[NSString stringWithFormat:@"%@ = ",ivar_name]];
                    initSql = [initSql stringByAppendingString:@"'"];
                    initSql = [initSql stringByAppendingString:[NSString stringWithFormat:@"%@",value]];
                    initSql = [initSql stringByAppendingString:@"',"];
                    value = nil;
                }
            }else if (ivar_type == RuntimeObjectIvarTypeDoubleAndFloat){
                value = [model valueForKey:ivar_name];
            }else if (ivar_type == RuntimeObjectIvarTypeArray){
                
                NSArray *arrValue = [model valueForKey:ivar_name];
                NSMutableArray *arrm = [NSMutableArray arrayWithCapacity:arrValue.count];
                for (id model in arrValue) {
                    [arrm addObject:[model mj_keyValues]];
                }
                value = arrm.mj_JSONString;
                if (value) {
                    initSql = [initSql stringByAppendingString:[NSString stringWithFormat:@"%@ = ",ivar_name]];
                    initSql = [initSql stringByAppendingString:@"'"];
                    initSql = [initSql stringByAppendingString:[NSString stringWithFormat:@"%@",value]];
                    initSql = [initSql stringByAppendingString:@"',"];
                    value = nil;
                }
            }else if (ivar_type == RuntimeObjectIvarTypeData){
                NSData *data = [model valueForKey:ivar_name];
                value = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            }else if (ivar_type == RuntimeObjectIvarTypeImage){
                UIImage *image = [model valueForKey:ivar_name];
                NSString *timeSince1970 = [NSString stringForTimeSince1970];
                [UIImagePNGRepresentation(image) writeToFile:[self fullPathWithFileName:timeSince1970] atomically:YES];
                value = timeSince1970;
            }else{
                //判断字符串以---MLDB_AppendingIDForModelProperty---结尾
                if ([ivar_name hasSuffix:MLDB_AppendingIDForModelProperty]) {
                    //获取属性的值（是一个模型）
                    NSString *nameForPropertyModel = [ivar_name substringToIndex:ivar_name.length - MLDB_AppendingIDForModelProperty.length];
                    value = [model valueForKey:nameForPropertyModel];
                    if (value) {
//                        [self ml_updateDataWithModel:value primaryKey:primaryKey optiin:nil];
                        [self ml_saveDataWithModel:value primaryKey:MLDB_PrimaryKey option:nil];
                    }
                    value = [value valueForKey:primaryKey];
                }else {
                    if ([ivar_name isEqualToString:MLDB_PrimaryKey] ) ivar_name = model_primaryKey;
                    value = [model valueForKey:ivar_name];
                }
            }
            if (value && ![ivar_name isEqualToString:model_primaryKey]) initSql = [initSql stringByAppendingString:[NSString stringWithFormat:@"%@ = %@,",ivar_name,value]];
        }];
    }];
    initSql = [initSql substringToIndex:initSql.length -1];
    initSql = [initSql stringByAppendingString:sql2];
    BOOL  ok = [self executeUpdate:initSql];
    if (option) option(ok);

}

- (void )ml_saveDataWithModel:(id )model primaryKey:(NSString *)primaryKey option:(SaveOption )option{
    [self ml_exsitInDatabaseForModel:model primaryKey:primaryKey option:^(BOOL exist) {
        if (exist) {//update
            [self ml_updateDataWithModel:model primaryKey:primaryKey optiin:^(BOOL update) {
                if (option) option(update);
            }];
        }else {//插入
            [self ml_insertDataWithModel:model primaryKey:primaryKey option:^(BOOL insert) {
                if (option) option(insert);
            }];
        }
    }];
}
- (void)ml_deleteDataWithModel:(id )model primaryKey:(NSString *)primaryKey option:(DeleteOption )option{
    
    model = [self ml_excuteDataWithModel:model option:nil];
    if (model == nil) return;
    
    NSString *table = NSStringFromClass([model class]);
    id value = nil;//model的主键值
    if ([[model class] ml_primaryKey].length > 0) {
        value = [model valueForKey:[[model class] ml_primaryKey]];
    }else{
     value = [model valueForKey:primaryKey];
    }
    if (value <= 0) return;

    
    /** 获取所有模型属性名和属性类型 */
    [[model class] ml_objectIvar_nameAndIvar_typeWithOption:^(MLDatabaseRuntimeIvar *ivar) {
        
        [[model class] ml_replaceKeyWithIvarName:ivar.name ivar_type:ivar.type option:^(MLDatabaseRuntimeIvar *ivar) {
            NSString *ivar_name = ivar.name;
            id valueOfIvarName = nil;
            if ([ivar.name hasSuffix:MLDB_AppendingIDForModelProperty]) {
                NSString *foreignKey = [ivar.name substringToIndex:ivar.name.length - MLDB_AppendingIDForModelProperty.length];
                valueOfIvarName = [model valueForKey:foreignKey];
                id classOfForeignKey = [[model class] ml_getClassForKeyIsObject][foreignKey];
                if (classOfForeignKey != nil && valueOfIvarName) {
                    //创建实例对象
//                    id instanceOfForeignKey = [[classOfForeignKey alloc]init];
                    id instanceOfForeignKey = valueOfIvarName;
                    // instanceOfForeignKey的主键
                    id primaryKeyOf_instanceOfForeignKey = nil;
                    if ([[instanceOfForeignKey class] ml_primaryKey]) {
                        primaryKeyOf_instanceOfForeignKey = [[instanceOfForeignKey class] ml_primaryKey];
                    }else{
                        primaryKeyOf_instanceOfForeignKey = MLDB_PrimaryKey;
                    }
                    //设置模型的主键值
                   // [instanceOfForeignKey setValue:valueOfIvarName forKey:primaryKeyOf_instanceOfForeignKey];
                    /** 在数据库查询该模型 */
                    id instanceInDatabase = [self ml_excuteDataWithModel:instanceOfForeignKey primaryKey:MLDB_PrimaryKey option:nil];
                    if (instanceInDatabase) {
                        [self ml_deleteDataWithModel:instanceInDatabase primaryKey:MLDB_PrimaryKey option:nil];
                    }
                }
            }else{
                
            }

        }];
        
    }];
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = %@",table,primaryKey,value];
    if (sql) {
        FMResultSet *set = [self executeQuery:sql];
        if ([set next]) {
            if (option) {
                option([set next]);
                [set close];
            }
        }
    }
    
    
}

- (void)ml_delDatasWithModel:(id )model primaryKey:(NSString *)primaryKey criteria:(NSString *)criteria deloption:(DeleteOption )option{
    NSString *table = NSStringFromClass([model class]);
    NSString *sql = [NSString stringWithFormat:@"delete from %@ %@",table,criteria];
    if (sql) {
        if ([self executeUpdate:sql]) {
            if (option) option(YES);
        }else{
            if (option) option(NO);
        }
    }
}

// 判断是否存在表
- (BOOL) isTableOK:(NSString *)tableName
{
    FMResultSet *rs = [self executeQuery:@"select count(*) as 'count' from sqlite_master where type ='table' and name = ?", tableName];
    while ([rs next])
    {
        // just print out what we've got in a number of formats.
        NSInteger count = [rs intForColumn:@"count"];
        NSLog(@"isTableOK %ld", (long)count);
        if (0 == count)
        {
            [rs close];
            return NO;
        }
        else
        {
            [rs close];
            return YES;
        }
    }
    [rs close];
    return NO;
}

//删除表
- (BOOL)ml_delTable:(NSString*)tableName{
    
    if (![self isTableOK:tableName]) {
        NSLog(@"表不存在");
        return NO;
    }
    NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
    if (![self executeUpdate:sqlstr])
    {
        NSLog(@"Delete table error!");
        return NO;
    }
    
    return YES;

}

// 清除表
- (BOOL)eraseTable:(NSString *)tableName
{
    
    if (![self isTableOK:tableName]) {
        NSLog(@"表不存在");
        return NO;
    }
    NSString *sqlstr = [NSString stringWithFormat:@"DELETE FROM %@", tableName];
    if (![self executeUpdate:sqlstr])
    {
        NSLog(@"Erase table error!");
        return NO;
    }
    
    return YES;
}

// 删除数据库
- (void)deleteDatabse{
   
    BOOL success;
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // delete the old db.
    if ([fileManager fileExistsAtPath:DBPath])
    {
        [self close];
        success = [fileManager removeItemAtPath:DBPath error:&error];
        if (!success) {
            NSAssert1(0, @"Failed to delete old database file with message '%@'.", [error localizedDescription]);
        }  
    }      


}

#pragma mark -- excuteDataWithModel
- (id )ml_excuteDataWithModel:(id )fmodel primaryKey:(NSString *)primaryKey option:(ExcuteOption )option{
    NSString *modelPrimaryKey = nil;
//    NSString *tablePrimaryKey = primaryKey;
    if ([[fmodel class] ml_primaryKey]) {
        modelPrimaryKey = [[fmodel class] ml_primaryKey];
    }else{
        modelPrimaryKey = primaryKey;
    }
    
    
    id fvalue = [fmodel valueForKey:modelPrimaryKey];
    id model = [[[fmodel class]alloc ]init];
    [model setValue:fvalue forKey:modelPrimaryKey];
    NSString * sql = [[model class ] ml_sqlForExcuteWithPrimaryKey:primaryKey value:[fmodel valueForKey:modelPrimaryKey]];
    FMResultSet *set= [self executeQuery:sql];
    while ([set next]) {
        [[model class ] ml_objectIvar_nameAndIvar_typeWithOption:^(MLDatabaseRuntimeIvar *ivar) {
            [[model class] ml_replaceKeyWithIvarName:ivar.name ivar_type:ivar.type option:^(MLDatabaseRuntimeIvar *ivar) {
                if (ivar.type == RuntimeObjectIvarTypeArray) {
                    NSString *jsonStr = [set stringForColumn:ivar.name];
                    NSArray *jsonArr = [jsonStr mj_JSONObject];
                    NSMutableArray *arrM = [NSMutableArray arrayWithCapacity:jsonArr.count];
                    
                    Class destclass = [[[model class] ml_propertyIsInstanceOfArray] objectForKey:ivar.name];
                    for (NSDictionary *dict in jsonArr) {
                        [arrM addObject:[destclass mj_objectWithKeyValues:dict]];
                    }
                    [model setValue:arrM forKey:ivar.name];
                }else if(ivar.type == RuntimeObjectIvarTypeData){
                    NSString *dataStr = [set stringForColumn:ivar.name];
                    [model setValue:[dataStr dataUsingEncoding:NSUTF8StringEncoding] forKey:ivar.name];
                }else if(ivar.type == RuntimeObjectIvarTypeImage){
                    NSString *imageName = [set stringForColumn:ivar.name];
                    UIImage *image = [UIImage imageWithContentsOfFile:[self fullPathWithFileName:imageName]];
                    [model setValue:image forKey:ivar.name];
                }else if (ivar.type == RuntimeObjectIvarTypeDoubleAndFloat){
                    [model setValue:@([set doubleForColumn:ivar.name]) forKey:ivar.name];
                }else if (ivar.type == RuntimeObjectIvarTypeObject){
                    [model setValue:[set stringForColumn:ivar.name] forKey:ivar.name];
                }else{
                    if ([ivar.name hasSuffix:MLDB_AppendingIDForModelProperty]) {//模型里面嵌套模型
                        id setValue = [set stringForColumn:ivar.name];
                        if ([setValue integerValue] > 0 ) {
                            NSString *realName = [ivar.name substringToIndex:ivar.name.length - MLDB_AppendingIDForModelProperty.length];
                            Class destClass = [[[model class] ml_getClassForKeyIsObject] objectForKey:realName];
                            id subModel = [[destClass alloc]init];
                            //如果主键有替换
                            [subModel setValue:setValue forKey:primaryKey];
                            id retModel = [self ml_excuteDataWithModel:subModel primaryKey:primaryKey option:nil];
                            [model setValue:retModel forKey:realName];
                        }
                    }else{//基本数据类型：long
                        if ([ivar.name isEqualToString:MLDB_PrimaryKey] && modelPrimaryKey) {
                            [model setValue:@([set longForColumn:ivar.name]) forKey:modelPrimaryKey];
                        }else{
                            [model setValue:@([set longForColumn:ivar.name]) forKey:ivar.name];
                        }
                    }
                }
            }];
        }];
    }
    if (option) option(model);
    return model;
}

//#pragma mark -- excuteDataWithModel
//- (id )ml_excuteDataWithModel:(id )fmodel primaryKey:(NSString *)primaryKey Alloption:(AllModelsOption )option{
//    NSString *modelPrimaryKey = nil;
//    //    NSString *tablePrimaryKey = primaryKey;
//    if ([[fmodel class] ml_primaryKey]) {
//        modelPrimaryKey = [[fmodel class] ml_primaryKey];
//    }else{
//        modelPrimaryKey = primaryKey;
//    }
//    
//    
//    id fvalue = [fmodel valueForKey:modelPrimaryKey];
//    id model = [[[fmodel class]alloc ]init];
//    [model setValue:fvalue forKey:modelPrimaryKey];
//    NSString * sql = [[model class ] ml_sqlForExcuteWithPrimaryKey:primaryKey value:[fmodel valueForKey:modelPrimaryKey]];
//    FMResultSet *set= [self executeQuery:sql];
//    while ([set next]) {
//        [[model class ] ml_objectIvar_nameAndIvar_typeWithOption:^(MLDatabaseRuntimeIvar *ivar) {
//            [[model class] ml_replaceKeyWithIvarName:ivar.name ivar_type:ivar.type option:^(MLDatabaseRuntimeIvar *ivar) {
//                if (ivar.type == RuntimeObjectIvarTypeArray) {
//                    NSString *jsonStr = [set stringForColumn:ivar.name];
//                    NSArray *jsonArr = [jsonStr mj_JSONObject];
//                    NSMutableArray *arrM = [NSMutableArray arrayWithCapacity:jsonArr.count];
//                    
//                    Class destclass = [[[model class] ml_propertyIsInstanceOfArray] objectForKey:ivar.name];
//                    for (NSDictionary *dict in jsonArr) {
//                        [arrM addObject:[destclass mj_objectWithKeyValues:dict]];
//                    }
//                    [model setValue:arrM forKey:ivar.name];
//                }else if(ivar.type == RuntimeObjectIvarTypeData){
//                    NSString *dataStr = [set stringForColumn:ivar.name];
//                    [model setValue:[dataStr dataUsingEncoding:NSUTF8StringEncoding] forKey:ivar.name];
//                }else if(ivar.type == RuntimeObjectIvarTypeImage){
//                    NSString *imageName = [set stringForColumn:ivar.name];
//                    UIImage *image = [UIImage imageWithContentsOfFile:[self fullPathWithFileName:imageName]];
//                    [model setValue:image forKey:ivar.name];
//                }else if (ivar.type == RuntimeObjectIvarTypeDoubleAndFloat){
//                    [model setValue:@([set doubleForColumn:ivar.name]) forKey:ivar.name];
//                }else if (ivar.type == RuntimeObjectIvarTypeObject){
//                    [model setValue:[set stringForColumn:ivar.name] forKey:ivar.name];
//                }else{
//                    if ([ivar.name hasSuffix:MLDB_AppendingIDForModelProperty]) {//模型里面嵌套模型
//                        id setValue = [set stringForColumn:ivar.name];
//                        if ([setValue integerValue] > 0 ) {
//                            NSString *realName = [ivar.name substringToIndex:ivar.name.length - MLDB_AppendingIDForModelProperty.length];
//                            Class destClass = [[[model class] ml_getClassForKeyIsObject] objectForKey:realName];
//                            id subModel = [[destClass alloc]init];
//                            //如果主键有替换
//                            [subModel setValue:setValue forKey:primaryKey];
//                            id retModel = [self ml_excuteDataWithModel:subModel primaryKey:primaryKey option:nil];
//                            [model setValue:retModel forKey:realName];
//                        }
//                    }else{//基本数据类型：long
//                        if ([ivar.name isEqualToString:MLDB_PrimaryKey] && modelPrimaryKey) {
//                            [model setValue:@([set longForColumn:ivar.name]) forKey:modelPrimaryKey];
//                        }else{
//                            [model setValue:@([set longForColumn:ivar.name]) forKey:ivar.name];
//                        }
//                    }
//                }
//            }];
//        }];
//    }
//    if (option) option(model);
//    return model;
//}

#pragma mark -- 查询所有
- (void)ml_excuteDatasWithModel:(id )model primaryKey:(NSString *)primaryKey option:(AllModelsOption )option{
    NSString *modelPrimaryKey = [[model class] ml_primaryKey];
    NSString *table = NSStringFromClass([model class]);
    NSString *sql = [NSString stringWithFormat:@"select * from %@",table];
    NSMutableArray *arr = [NSMutableArray array];
    FMResultSet *set = [self executeQuery:sql];
    while ([set next]) {
        id submodel = [[[model class] alloc]init];
        id value = [set stringForColumn:primaryKey];
        if (modelPrimaryKey) {
            [submodel setValue:value forKey:modelPrimaryKey];
        }else{
        [submodel setValue:value forKey:primaryKey];
        }
        submodel = [self ml_excuteDataWithModel:submodel primaryKey:primaryKey option:nil];
        [arr addObject:submodel];
    }
    if (option) option(arr);
    
}

#pragma mark -- 查询所有
- (void)ml_excuteDatasWithModel:(id )model primaryKey:(NSString *)primaryKey criteria:(NSString *)criteria option:(AllModelsOption )option{
    NSString *modelPrimaryKey = [[model class] ml_primaryKey];
    NSString *table = NSStringFromClass([model class]);
    NSString *sql = [NSString stringWithFormat:@"select * from %@ %@",table,criteria];
    NSMutableArray *arr = [NSMutableArray array];
    FMResultSet *set = [self executeQuery:sql];
    while ([set next]) {
        id submodel = [[[model class] alloc]init];
        id value = [set stringForColumn:primaryKey];
        if (modelPrimaryKey) {
            [submodel setValue:value forKey:modelPrimaryKey];
        }else{
            [submodel setValue:value forKey:primaryKey];
        }
        submodel = [self ml_excuteDataWithModel:submodel primaryKey:primaryKey option:nil];
        [arr addObject:submodel];
    }
    if (option) option(arr);
}


#define MMAppHomePath_DocumentDirectory     [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#pragma mark -- PrivateMethod
/** 根据文件名获取文件全路径 */
- (NSString *)fullPathWithFileName:(NSString *)fileName{
    return [MMAppHomePath_DocumentDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MLDatabase%@",fileName]];
}
@end
