//
//  SCManiphestTicketCreator.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/16/18.
//

#import <Foundation/Foundation.h>

/**
 Protocol for filing jira tickets and beta s2r.
 */
@protocol SCManiphestTicketCreator

- (void)createAndFile:(NSData *)image
         creationTime:(long)reportCreationTime
          description:(NSString *)bugDescription
                email:(NSString *)otherEmail
              project:(NSString *)projectName
           subproject:(NSString *)subprojectName;

- (void)createAndFileBetaReport:(NSString *)msg;

@end
