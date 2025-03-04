import { DomainModule } from '@app/domain';
import { InfraModule } from '@app/infra';
import { AssetEntity, ExifEntity } from '@app/infra/entities';
import { Module, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AssetRepository, IAssetRepository } from './api-v1/asset/asset-repository';
import { AssetController as AssetControllerV1 } from './api-v1/asset/asset.controller';
import { AssetService } from './api-v1/asset/asset.service';
import { AppGuard } from './app.guard';
import { FileUploadInterceptor } from './app.interceptor';
import { AppService } from './app.service';
import {
  AlbumController,
  APIKeyController,
  AppController,
  AssetController,
  AuditController,
  AuthController,
  JobController,
  OAuthController,
  PartnerController,
  PersonController,
  SearchController,
  ServerInfoController,
  SharedLinkController,
  SystemConfigController,
  TagController,
  UserController,
} from './controllers';

@Module({
  imports: [
    //
    DomainModule.register({ imports: [InfraModule] }),
    ScheduleModule.forRoot(),
    TypeOrmModule.forFeature([AssetEntity, ExifEntity]),
  ],
  controllers: [
    AssetController,
    AssetControllerV1,
    AppController,
    AlbumController,
    APIKeyController,
    AuditController,
    AuthController,
    JobController,
    OAuthController,
    PartnerController,
    SearchController,
    ServerInfoController,
    SharedLinkController,
    SystemConfigController,
    TagController,
    UserController,
    PersonController,
  ],
  providers: [
    //
    { provide: APP_GUARD, useExisting: AppGuard },
    { provide: IAssetRepository, useClass: AssetRepository },
    AppGuard,
    AppService,
    AssetService,
    FileUploadInterceptor,
  ],
})
export class AppModule implements OnModuleInit, OnModuleDestroy {
  constructor(private appService: AppService) {}

  async onModuleInit() {
    await this.appService.init();
  }

  onModuleDestroy() {
    this.appService.destroy();
  }
}
