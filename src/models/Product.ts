export interface Product {
  _id: string;
  nombre: string;
  descripcion?: string;
  precio: number;
  costo: number;
  categoria: string; // Category ID
  imagenUrl?: string;
  disponible: boolean;
  tipoProducto: 'individual' | 'combo' | 'ingrediente';
  ingredientes?: string[]; // Array of ingredient IDs for combos
  unidadMedida?: string;
  stock?: number;
  fechaCreacion?: string;
  fechaActualizacion?: string;
}

export interface ProductResponse {
  success: boolean;
  message: string;
  data: Product[];
  meta: any;
  timestamp: string;
}

export interface CreateProductRequest {
  nombre: string;
  descripcion?: string;
  precio: number;
  costo: number;
  categoria: string;
  imagenUrl?: string;
  disponible: boolean;
  tipoProducto: 'individual' | 'combo' | 'ingrediente';
  ingredientes?: string[];
  unidadMedida?: string;
  stock?: number;
}

export interface UpdateProductRequest extends Partial<CreateProductRequest> {
  _id: string;
}
