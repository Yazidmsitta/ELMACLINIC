import { z } from 'zod';
export const expenseFields=z.object({description:z.string().trim().min(1).max(2000),category:z.string().trim().min(1).max(100),
  amount_centimes:z.number().int().positive().max(2147483647),spent_on:z.iso.date()}).strict();
