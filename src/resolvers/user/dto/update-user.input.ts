import { InputType, Field } from '@nestjs/graphql';
import { MaxLength } from 'class-validator';

@InputType()
export class UpdateUserInput {
  @Field({ nullable: true })
  @MaxLength(100)
  firstname?: string;

  @Field({ nullable: true })
  @MaxLength(100)
  lastname?: string;
}
