ALTER TABLE "PRT_ENVIRONMENTS" ADD CONSTRAINT "PRT_ENVIRONMENTS_FK1" FOREIGN KEY ("ORGANIZATION_ID")
	  REFERENCES "PRT_ORGANIZATIONS" ("ORGANIZATION_ID") ON DELETE CASCADE ENABLE;