import { z } from 'zod';
export const productFields = z.object({
  sku: z.string().trim().min(1).max(100), name: z.string().trim().min(1).max(200),
  unit: z.string().trim().min(1).max(40), cost_centimes: z.number().int().min(0).max(2147483647),
  reorder_level: z.string().regex(/^\d{1,9}(?:\.\d{1,3})?$/), active: z.boolean(),
}).strict();
export function productArgs(body: z.infer<typeof productFields>) {
  return { sku_text: body.sku, name_text: body.name, unit_text: body.unit,
    cost: body.cost_centimes, threshold: body.reorder_level, enabled: body.active };
}
