import React, { useState } from 'react';
import { useRouter } from 'next/router';
import ProductForm from '../../components/ProductForm';
import { CreateProductRequest } from '../../models/Product';
import { ProductService } from '../../services/productService';

const NewProductPage: React.FC = () => {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>('');

  const handleSubmit = async (productData: CreateProductRequest) => {
    try {
      setIsLoading(true);
      setError('');
      
      const newProduct = await ProductService.createProduct(productData);
      
      // Redirect to the product detail page
      router.push(`/products/${newProduct._id}`);
    } catch (err) {
      setError('Error creating product. Please try again.');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancel = () => {
    router.push('/products');
  };

  return (
    <div className="container mx-auto px-4 py-8">
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-6">
          <div className="flex">
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">Error</h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{error}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <ProductForm
        onSubmit={handleSubmit}
        onCancel={handleCancel}
        isLoading={isLoading}
        isEdit={false}
      />
    </div>
  );
};

export default NewProductPage;
