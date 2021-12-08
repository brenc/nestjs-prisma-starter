import { GraphQLModule } from '@nestjs/graphql';
import { Module } from '@nestjs/common';
import { AppController } from './controllers/app.controller';
import { AppService } from './services/app.service';
import { AuthModule } from './resolvers/auth/auth.module';
import { UserModule } from './resolvers/user/user.module';
import { PostModule } from './resolvers/post/post.module';
import { AppResolver } from './resolvers/app.resolver';
import { DateScalar } from './common/scalars/date.scalar';
import { ConfigModule, ConfigService } from '@nestjs/config';
import config from './configs/config';
import { GraphqlConfig } from './configs/config.interface';
import { PrismaModule } from 'nestjs-prisma';
import * as Joi from 'joi';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,

      load: [config],

      validationOptions: {
        abortEarly: false,
        allowUnknown: true,
      },

      validationSchema: Joi.object({
        DB_HOST: Joi.string().required(),

        DB_URL: Joi.string().required(),

        DB_USER: Joi.string().required(),

        JWT_ACCESS_SECRET: Joi.string().required(),

        JWT_REFRESH_SECRET: Joi.string().required(),

        MYSQL_ROOT_PASSWORD: Joi.string().required(),

        NODE_ENV: Joi.string()
          .valid('development', 'production')
          .default('development'),

        PORT: Joi.number().default(3000),
      }),
    }),

    GraphQLModule.forRootAsync({
      useFactory: async (configService: ConfigService) => {
        const graphqlConfig = configService.get<GraphqlConfig>('graphql');

        return {
          installSubscriptionHandlers: true,

          buildSchemaOptions: {
            numberScalarMode: 'integer',
          },

          sortSchema: graphqlConfig.sortSchema,

          autoSchemaFile:
            graphqlConfig.schemaDestination || './src/schema.graphql',

          debug: graphqlConfig.debug,

          playground: graphqlConfig.playgroundEnabled,

          context: ({ req }) => ({ req }),
        };
      },

      inject: [ConfigService],
    }),

    PrismaModule.forRoot({
      isGlobal: true,
    }),

    AuthModule,

    UserModule,

    PostModule,
  ],

  controllers: [AppController],

  providers: [AppService, AppResolver, DateScalar],
})
export class AppModule {}
