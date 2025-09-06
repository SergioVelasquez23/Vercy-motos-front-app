import { Product, ProductResponse, CreateProductRequest, UpdateProductRequest } from '../models/Product';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

export class ProductService {
  private static async handleResponse<T>(response: Response): Promise<T> {
    if (!response.ok) {
      const error = await response.json().catch(() => ({
        message: `HTTP ${response.status}: ${response.statusText}`
      }));
      throw new Error(error.message || 'An error occurred');
    }
    return response.json();
  }

  static async getAllProducts(): Promise<Product[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos`);
      const data = await this.handleResponse<ProductResponse>(response);
      return data.data;
    } catch (error) {
      console.error('Error fetching products:', error);
      throw error;
    }
  }

  static async getProductById(id: string): Promise<Product> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos/${id}`);
      const data = await this.handleResponse<{ data: Product }>(response);
      return data.data;
    } catch (error) {
      console.error('Error fetching product:', error);
      throw error;
    }
  }

  static async getProductsByCategory(categoryId: string): Promise<Product[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos?categoria=${categoryId}`);
      const data = await this.handleResponse<ProductResponse>(response);
      return data.data;
    } catch (error) {
      console.error('Error fetching products by category:', error);
      throw error;
    }
  }

  static async createProduct(product: CreateProductRequest): Promise<Product> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(product),
      });
      const data = await this.handleResponse<{ data: Product }>(response);
      return data.data;
    } catch (error) {
      console.error('Error creating product:', error);
      throw error;
    }
  }

  static async updateProduct(id: string, product: Partial<UpdateProductRequest>): Promise<Product> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(product),
      });
      const data = await this.handleResponse<{ data: Product }>(response);
      return data.data;
    } catch (error) {
      console.error('Error updating product:', error);
      throw error;
    }
  }

  static async deleteProduct(id: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos/${id}`, {
        method: 'DELETE',
      });
      await this.handleResponse<{ success: boolean }>(response);
    } catch (error) {
      console.error('Error deleting product:', error);
      throw error;
    }
  }

  static async searchProducts(query: string): Promise<Product[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/productos/search?q=${encodeURIComponent(query)}`);
      const data = await this.handleResponse<ProductResponse>(response);
      return data.data;
    } catch (error) {
      console.error('Error searching products:', error);
      throw error;
    }
  }
}
